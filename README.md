# ADMIN STORE

Premium multi-category e-commerce starter for Bangladesh.

## Stack
- React + Vite
- Supabase (Postgres, Auth, Storage)
- Cloudflare Pages

## Local development

```bash
npm install
npm run dev
```

Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in `.env.local`.

## Build

```bash
npm run build
```

Cloudflare Pages uses `npm run build` and publishes `dist/`.
