# Nivo Shop

Premium, responsive multi-category e-commerce storefront for Bangladesh.

## Production stack
- Storefront and admin management: HTML, Tailwind CSS and JavaScript
- Backend: Supabase Auth, PostgreSQL, Row Level Security and Storage
- Hosting and automatic deployments: Cloudflare Pages connected to GitHub
- Repository: https://github.com/ijaz-ahmed-2026/admin-store
- Production branch: `nivo-shop-rebuild`
- Supabase project: `vgrcoalmlvirwlnhjkiz`

## Categories
Health & Beauty, Cleaning Items, Daily Accessories, Gadgets, Home & Decor, Kitchen Items, Combo Offer.

## Cloudflare Pages build
- Build command: `npm run build`
- Output directory: `dist`
- Production URL: https://nivo-shop.pages.dev

## Admin
Open the storefront and choose **Admin Manager**. Sign in using the Supabase account whose `profiles.role` is `admin`. The existing authorized admin profile is retained. Never expose the Supabase service-role key in browser code.

## Supabase
The migration in `supabase/migrations` seeds the Nivo Shop categories and store settings, configures media bucket limits, and hardens public order placement with server-side pricing, stock validation and inventory decrement.

## Local development
```bash
npm install
npm run build
npm run dev
```
