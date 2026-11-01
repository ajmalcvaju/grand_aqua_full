'use client';

import React, { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import NotificationBell from '@/components/NotificationBell';
import {
  LayoutDashboard,
  Users,
  Award,
  Tag,
  CreditCard,
  Layers,
  Package,
  UserCheck,
  TrendingUp,
  FileText,
  ShoppingCart,
  DollarSign,
  Settings,
  Bell,
  LogOut,
  Droplet,
  Search,
  Image as ImageIcon,
  Menu,
  X,
  ChevronRight,
  ShieldAlert,
  Gift,
} from 'lucide-react';

const NAV_ITEMS = [
  { name: 'Dashboard', href: '/dashboard', icon: LayoutDashboard },
  { name: 'Buyers (4 Categories)', href: '/dashboard/buyers', icon: Users },
  { name: 'Loyalty & Gift Rewards', href: '/dashboard/loyalty', icon: Gift },
  { name: 'Search Keywords', href: '/dashboard/search-keywords', icon: Search },
  { name: 'Credit Management', href: '/dashboard/credit', icon: CreditCard },
  { name: 'Category Management', href: '/dashboard/categories', icon: Layers },
  { name: 'Banner Management', href: '/dashboard/banners', icon: ImageIcon },
  { name: 'Products & 4-Tier Pricing', href: '/dashboard/products', icon: Package },
  { name: 'Salesman Management', href: '/dashboard/salesmen', icon: UserCheck },
  { name: 'Quotations & Approvals', href: '/dashboard/quotations', icon: FileText },
  { name: 'Order Management', href: '/dashboard/orders', icon: ShoppingCart },
  { name: 'Payments & Receivables', href: '/dashboard/payments', icon: DollarSign },
  { name: 'Settings & Admin Roles', href: '/dashboard/settings', icon: Settings },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const { user, logout } = useAuth();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col lg:flex-row">
      {/* Mobile Top Header */}
      <div className="lg:hidden bg-slate-900 text-white px-4 py-3 flex items-center justify-between border-b border-slate-800">
        <div className="flex items-center gap-2">
          <Droplet className="w-6 h-6 text-sky-400 fill-sky-400" />
          <span className="font-bold tracking-wider">GRAND AQUA ADMIN</span>
        </div>
        <div className="flex items-center gap-2">
          <NotificationBell />
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="p-1.5 text-slate-400 hover:text-white"
          >
            {mobileMenuOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
        </div>
      </div>

      {/* Sidebar Navigation */}
      <aside
        className={`fixed inset-y-0 left-0 z-40 w-64 bg-slate-900 text-slate-300 flex flex-col border-r border-slate-800 transition-transform duration-200 lg:static lg:translate-x-0 ${
          mobileMenuOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* Brand Area */}
        <div className="p-5 border-b border-slate-800">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-sky-600 to-cyan-500 flex items-center justify-center text-white shadow-lg shadow-sky-500/20">
              <Droplet className="w-6 h-6 fill-white" />
            </div>
            <div>
              <h1 className="font-extrabold text-white tracking-wide text-lg leading-tight">
                GRAND AQUA
              </h1>
              <p className="text-[10px] uppercase tracking-widest text-sky-400 font-semibold">
                Pure • Safe • Healthy
              </p>
            </div>
          </div>
        </div>

        {/* User Mini Card */}
        <div className="px-4 py-3 m-3 bg-slate-800/60 rounded-xl border border-slate-700/50 flex items-center justify-between">
          <div className="truncate">
            <p className="text-xs font-bold text-white truncate">{user?.fullName || 'Super Admin'}</p>
            <p className="text-[10px] text-sky-400 uppercase font-mono">{user?.role || 'SUPER_ADMIN'}</p>
          </div>
          <button
            onClick={logout}
            title="Logout"
            className="p-1.5 text-slate-400 hover:text-red-400 hover:bg-slate-700/50 rounded-lg transition-colors"
          >
            <LogOut className="w-4 h-4" />
          </button>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 px-3 py-2 space-y-1 overflow-y-auto">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const isActive = pathname === item.href;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileMenuOpen(false)}
                className={`flex items-center gap-3 px-3.5 py-2.5 rounded-xl text-xs font-medium transition-all ${
                  isActive
                    ? 'bg-sky-600 text-white font-semibold shadow-md shadow-sky-600/30'
                    : 'text-slate-400 hover:text-white hover:bg-slate-800/60'
                }`}
              >
                <Icon className={`w-4 h-4 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                <span className="flex-1">{item.name}</span>
                {isActive && <ChevronRight className="w-3.5 h-3.5 text-sky-200" />}
              </Link>
            );
          })}
        </nav>

        {/* Footer Info */}
        <div className="p-4 border-t border-slate-800 text-[11px] text-slate-500 text-center">
          Grand Aqua Platform v1.0.0
          <br />
          <span className="text-emerald-500 font-medium">● Server Connected</span>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        {/* Top Navbar */}
        <header className="hidden lg:flex bg-white h-16 border-b border-slate-200 px-8 items-center justify-between">
          <div>
            <h2 className="text-base font-bold text-slate-800">
              Grand Aqua Enterprise Management System
            </h2>
            <p className="text-xs text-slate-500">
              Wholesale & Retail Commercial Operations Dashboard
            </p>
          </div>

          <div className="flex items-center gap-4">
            <span className="inline-flex items-center gap-1.5 px-3 py-1 bg-emerald-50 text-emerald-700 border border-emerald-200 rounded-full text-xs font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>
              Live Node API / PostgreSQL
            </span>

            <NotificationBell />

            <div className="h-4 w-px bg-slate-200"></div>

            <button
              onClick={logout}
              className="flex items-center gap-1.5 text-xs text-slate-600 hover:text-red-600 font-medium transition-colors"
            >
              <LogOut className="w-4 h-4" />
              <span>Logout</span>
            </button>
          </div>
        </header>

        {/* Body Content */}
        <main className="flex-1 p-6 lg:p-8 overflow-y-auto">{children}</main>
      </div>
    </div>
  );
}
