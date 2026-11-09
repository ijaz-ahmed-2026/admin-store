-- Nivo Shop production configuration and order inventory safeguards
insert into public.categories (name, slug, sort_order, is_active)
values ('Health & Beauty','health-beauty',1,true),('Cleaning Items','cleaning-items',2,true),('Daily Accessories','daily-accessories',3,true),('Gadgets','gadgets',4,true),('Home & Decor','home-decor',5,true),('Kitchen Items','kitchen-items',6,true),('Combo Offer','combo-offer',7,true)
on conflict (slug) do update set name=excluded.name,sort_order=excluded.sort_order,is_active=true;
update public.categories set is_active=false where slug not in ('health-beauty','cleaning-items','daily-accessories','gadgets','home-decor','kitchen-items','combo-offer');
insert into public.store_settings(key,value,updated_at) values
('store','{"name":"Nivo Shop","tagline":"Everyday essentials, thoughtfully found","currency":"BDT","language":"bn-en"}'::jsonb,now()),
('store_banner','"Discover thoughtful finds for better everyday living."'::jsonb,now()),
('store_notice','"Delivery across Bangladesh"'::jsonb,now())
on conflict(key) do update set value=excluded.value,updated_at=now();
update storage.buckets set public=true,file_size_limit=104857600,allowed_mime_types=array['image/jpeg','image/png','image/webp','image/avif'] where id='product-images';
update storage.buckets set public=true,file_size_limit=104857600,allowed_mime_types=array['video/mp4','video/webm','video/quicktime'] where id='product-media';
create or replace function public.place_public_order(p_customer_name text,p_phone text,p_division text,p_district text,p_thana text,p_address text,p_delivery_note text,p_delivery_zone text,p_payment_method text,p_payment_reference text,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $function$
declare
 v_order_id uuid; v_order_number text; v_subtotal numeric:=0; v_delivery numeric:=0; v_discount numeric:=0; v_total numeric:=0; v_advance numeric:=0;
 v_item record; v_product public.products%rowtype; v_inside numeric:=60; v_outside numeric:=120; v_zone text:=lower(coalesce(p_delivery_zone,''));
begin
 if length(trim(coalesce(p_customer_name,'')))<2 then raise exception 'Please enter customer name'; end if;
 if length(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'))<10 then raise exception 'Please enter a valid phone number'; end if;
 if length(trim(coalesce(p_division,'')))<2 or length(trim(coalesce(p_district,'')))<2 or length(trim(coalesce(p_thana,'')))<2 then raise exception 'Please select division, district and thana'; end if;
 if length(trim(coalesce(p_address,'')))<5 then raise exception 'Please enter full address'; end if;
 if v_zone not in ('inside_dhaka','outside_dhaka') then raise exception 'Please select delivery area'; end if;
 if p_payment_method is null or p_payment_method not in ('cod','bkash','nagad') then raise exception 'Invalid payment method'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>30 then raise exception 'Cart must contain 1 to 30 products'; end if;
 select coalesce((value #>> '{}')::numeric,60) into v_inside from public.store_settings where key='delivery_inside_dhaka';
 select coalesce((value #>> '{}')::numeric,120) into v_outside from public.store_settings where key='delivery_outside_dhaka';
 v_delivery:=case when v_zone='inside_dhaka' then v_inside else v_outside end;
 for v_item in select (x->>'id')::uuid product_id,sum((x->>'qty')::integer)::integer qty from jsonb_array_elements(p_items) x group by (x->>'id')::uuid loop
  if v_item.qty is null or v_item.qty<1 or v_item.qty>50 then raise exception 'Invalid product quantity'; end if;
  select * into v_product from public.products where id=v_item.product_id and is_active=true for update;
  if not found then raise exception 'A product is no longer available'; end if;
  if v_product.stock<v_item.qty then raise exception 'Insufficient stock for %',v_product.name; end if;
  v_subtotal:=v_subtotal+v_product.price*v_item.qty;
 end loop;
 if p_payment_method in ('bkash','nagad') then
  v_discount:=case when v_zone='inside_dhaka' then 49 else 0 end;
  v_advance:=case when v_zone='outside_dhaka' then v_delivery else v_subtotal+v_delivery-v_discount end;
  if length(trim(coalesce(p_payment_reference,'')))<4 then raise exception 'Enter the payment transaction ID/reference'; end if;
 elsif v_zone='outside_dhaka' then raise exception 'Outside Dhaka orders require advance delivery-charge payment by bKash or Nagad'; end if;
 v_total:=greatest(0,v_subtotal+v_delivery-v_discount);
 v_order_number:='NV'||to_char(now(),'YYMMDD')||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
 insert into public.orders(order_number,user_id,customer_name,phone,division,district,thana,address,delivery_note,subtotal,delivery_charge,discount,total,payment_method,payment_status,status,payment_reference,delivery_zone,advance_amount)
 values(v_order_number,auth.uid(),trim(p_customer_name),trim(p_phone),trim(p_division),trim(p_district),trim(p_thana),trim(p_address),nullif(trim(coalesce(p_delivery_note,'')),''),v_subtotal,v_delivery,v_discount,v_total,p_payment_method,case when p_payment_method='cod' then 'unpaid' else 'pending' end,'pending',nullif(trim(coalesce(p_payment_reference,'')),''),v_zone,v_advance) returning id into v_order_id;
 insert into public.order_items(order_id,product_id,product_name,unit_price,quantity,line_total)
 select v_order_id,p.id,p.name,p.price,x.qty,p.price*x.qty from (select (x->>'id')::uuid product_id,sum((x->>'qty')::integer)::integer qty from jsonb_array_elements(p_items) x group by (x->>'id')::uuid) x join public.products p on p.id=x.product_id;
 update public.products p set stock=p.stock-x.qty,updated_at=now() from (select (x->>'id')::uuid product_id,sum((x->>'qty')::integer)::integer qty from jsonb_array_elements(p_items) x group by (x->>'id')::uuid) x where p.id=x.product_id;
 return jsonb_build_object('id',v_order_id,'order_number',v_order_number,'subtotal',v_subtotal,'delivery_charge',v_delivery,'discount',v_discount,'total',v_total,'advance_amount',v_advance);
end;$function$;
grant execute on function public.place_public_order(text,text,text,text,text,text,text,text,text,text,jsonb) to anon,authenticated;
