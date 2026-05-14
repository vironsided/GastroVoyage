import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'GastroVoyage Admin',
  description: 'Manage countries, restaurants, partners, and analytics for GastroVoyage.',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-parchment-50 text-navy-900 antialiased">{children}</body>
    </html>
  );
}
