'use client';

import './globals.css';
import { AuthProvider } from '@/lib/auth-context';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            refetchOnWindowFocus: false,
            retry: 1,
          },
        },
      }),
  );

  return (
    <html lang="en">
      <head>
        <title>Grand Aqua — Salesman Workspace</title>
        <meta name="description" content="Field Sales, Quotation Pipeline, and Incentive Management" />
      </head>
      <body className="antialiased bg-slate-50 text-slate-900">
        <QueryClientProvider client={queryClient}>
          <AuthProvider>{children}</AuthProvider>
        </QueryClientProvider>
      </body>
    </html>
  );
}
