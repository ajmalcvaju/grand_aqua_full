'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  TrendingUp,
  Users,
  DollarSign,
  ShoppingCart,
  FileText,
  AlertTriangle,
  Award,
  CreditCard,
  CheckCircle,
  Clock,
  ArrowUpRight,
  Filter,
} from 'lucide-react';
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  PieChart,
  Pie,
  Cell,
  Legend,
} from 'recharts';

const COLORS = ['#0284c7', '#0d9488', '#eab308', '#64748b', '#ef4444'];

export default function AdminDashboardPage() {
  const [period, setPeriod] = useState('month');

  const { data: dashboard, isLoading, error } = useQuery({
    queryKey: ['admin-dashboard', period],
    queryFn: () => api.get(`/reports/dashboard?period=${period}`),
  });

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center space-y-3">
          <div className="w-10 h-10 border-4 border-sky-600 border-t-transparent rounded-full animate-spin mx-auto"></div>
          <p className="text-sm font-medium text-slate-500">Loading Grand Aqua operational metrics...</p>
        </div>
      </div>
    );
  }

  const overview = (dashboard as any)?.overview || {};
  const buyersBreakdown = (dashboard as any)?.buyersBreakdown || {};
  const charts = (dashboard as any)?.charts || {};
  const bestSelling = (dashboard as any)?.bestSellingProducts || [];
  const lowStock = (dashboard as any)?.lowStockProducts || [];

  const orderStatusData = [
    { name: 'Pending', count: charts.ordersByStatus?.pending || 0 },
    { name: 'Confirmed', count: charts.ordersByStatus?.confirmed || 0 },
    { name: 'Processing', count: charts.ordersByStatus?.processing || 0 },
    { name: 'Shipped', count: charts.ordersByStatus?.shipped || 0 },
    { name: 'Delivered', count: charts.ordersByStatus?.delivered || 0 },
    { name: 'Cancelled', count: charts.ordersByStatus?.cancelled || 0 },
  ];

  const buyerData = charts.buyerDistribution || [];

  return (
    <div className="space-y-8">
      {/* Page Header with Date Filter */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Executive Dashboard</h1>
          <p className="text-sm text-slate-500">
            Real-time business performance, 4-tier sales velocity, and financial receivables.
          </p>
        </div>

        {/* Date Filter Tabs */}
        <div className="flex items-center bg-white p-1 rounded-xl border border-slate-200 shadow-sm">
          {[
            { id: 'today', label: 'Today' },
            { id: '7days', label: 'Last 7 Days' },
            { id: 'month', label: 'This Month' },
            { id: 'lastMonth', label: 'Last Month' },
          ].map((tab) => (
            <button
              key={tab.id}
              onClick={() => setPeriod(tab.id)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-all ${
                period === tab.id
                  ? 'bg-sky-600 text-white shadow-sm'
                  : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Top Financial & Operational Metric Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Total Sales Value</span>
            <div className="p-2 bg-sky-50 text-sky-600 rounded-xl">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-slate-900">
              ₹{Number(overview.totalSales || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
            </div>
            <p className="text-xs text-emerald-600 font-medium flex items-center gap-1 mt-1">
              <ArrowUpRight className="w-3.5 h-3.5" /> Direct Net Sales across all channels
            </p>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Collected Payments</span>
            <div className="p-2 bg-emerald-50 text-emerald-600 rounded-xl">
              <CheckCircle className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-slate-900">
              ₹{Number(overview.paymentsCollected || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
            </div>
            <p className="text-xs text-slate-500 font-medium mt-1">Cash, UPI, and Bank Settlements</p>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Outstanding Receivables</span>
            <div className="p-2 bg-amber-50 text-amber-600 rounded-xl">
              <Clock className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-amber-600">
              ₹{Number(overview.outstandingReceivables || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
            </div>
            <p className="text-xs text-slate-500 font-medium mt-1">Pending payments from trade buyers</p>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm relative overflow-hidden">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Credit Facility</span>
            <div className="p-2 bg-purple-50 text-purple-600 rounded-xl">
              <CreditCard className="w-5 h-5" />
            </div>
          </div>
          <div className="mt-4">
            <div className="text-2xl font-black text-slate-900">
              ₹{Number(overview.credit?.utilized || 0).toLocaleString('en-IN')} / ₹{Number(overview.credit?.totalLimit || 0).toLocaleString('en-IN')}
            </div>
            <p className="text-xs text-purple-700 font-medium mt-1">
              ₹{Number(overview.credit?.available || 0).toLocaleString('en-IN')} available credit
            </p>
          </div>
        </div>
      </div>

      {/* Secondary Metrics: Buyers & Quotations */}
      <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-6 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-slate-400">Total Buyers</span>
          <p className="text-xl font-extrabold text-slate-900 mt-1">{overview.totalBuyers || 0}</p>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-sky-600">Distributors</span>
          <p className="text-xl font-extrabold text-sky-700 mt-1">{buyersBreakdown.distributors || 0}</p>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-cyan-600">Wholesalers</span>
          <p className="text-xl font-extrabold text-cyan-700 mt-1">{buyersBreakdown.wholesalers || 0}</p>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-teal-600">Dealers / Retailers</span>
          <p className="text-xl font-extrabold text-teal-700 mt-1">{buyersBreakdown.dealers || 0}</p>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-amber-600">Awaiting Discount Approval</span>
          <p className="text-xl font-extrabold text-amber-600 mt-1">{overview.quotationsPendingApproval || 0}</p>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 text-center">
          <span className="text-[11px] font-bold uppercase text-emerald-600">Active Sales Force</span>
          <p className="text-xl font-extrabold text-emerald-600 mt-1">{overview.activeSalesmen || 0}</p>
        </div>
      </div>

      {/* Visual Charts Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Order Status Breakdown */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <h2 className="text-base font-bold text-slate-900 mb-4 flex items-center gap-2">
            <ShoppingCart className="w-5 h-5 text-sky-600" />
            Orders Pipeline by Operational Status
          </h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={orderStatusData}>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f1f5f9" />
                <XAxis dataKey="name" stroke="#64748b" fontSize={11} />
                <YAxis stroke="#64748b" fontSize={11} allowDecimals={false} />
                <Tooltip />
                <Bar dataKey="count" fill="#0284c7" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* Buyer Distribution */}
        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <h2 className="text-base font-bold text-slate-900 mb-4 flex items-center gap-2">
            <Users className="w-5 h-5 text-sky-600" />
            Registered Buyer Category Distribution
          </h2>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={buyerData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={85}
                  paddingAngle={5}
                  dataKey="count"
                  nameKey="type"
                  label={({ type, count }) => `${type}: ${count}`}
                >
                  {buyerData.map((entry: any, index: number) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip />
                <Legend />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Best Selling Products & Low Stock Alerts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <h2 className="text-base font-bold text-slate-900 mb-4 flex items-center gap-2">
            <Award className="w-5 h-5 text-amber-500" />
            Top Selling Water Purifiers & Systems
          </h2>
          <div className="divide-y divide-slate-100">
            {bestSelling.map((prod: any, idx: number) => (
              <div key={prod.id} className="py-3 flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <span className="w-6 h-6 rounded-full bg-slate-100 text-slate-600 text-xs font-bold flex items-center justify-center">
                    {idx + 1}
                  </span>
                  <div>
                    <p className="text-sm font-semibold text-slate-800">{prod.name}</p>
                    <p className="text-xs text-slate-400 font-mono">SKU: {prod.sku}</p>
                  </div>
                </div>
                <div className="text-right">
                  <span className="text-xs font-bold text-sky-600 px-2.5 py-1 bg-sky-50 rounded-lg">
                    {prod.ordersCount} Orders
                  </span>
                  <p className="text-[11px] text-slate-400 mt-1">{prod.stock} in stock</p>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm">
          <h2 className="text-base font-bold text-slate-900 mb-4 flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-red-500" />
            Inventory Reorder & Low-Stock Alerts
          </h2>
          {lowStock.length === 0 ? (
            <div className="text-center py-10 text-slate-400 text-sm">
              <CheckCircle className="w-8 h-8 text-emerald-500 mx-auto mb-2" />
              All inventory levels are above reorder thresholds.
            </div>
          ) : (
            <div className="divide-y divide-slate-100">
              {lowStock.map((prod: any) => (
                <div key={prod.id} className="py-3 flex items-center justify-between">
                  <div>
                    <p className="text-sm font-semibold text-slate-800">{prod.name}</p>
                    <p className="text-xs text-slate-400 font-mono">SKU: {prod.sku}</p>
                  </div>
                  <div className="text-right">
                    <span className="px-2.5 py-1 bg-red-50 text-red-600 text-xs font-bold rounded-lg border border-red-200">
                      Stock: {prod.currentStock}
                    </span>
                    <p className="text-[11px] text-slate-400 mt-1">Reorder level: {prod.reorderLevel}</p>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
