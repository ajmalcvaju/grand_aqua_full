'use client';

import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Store,
  TrendingUp,
  FileText,
  ShoppingCart,
  DollarSign,
  Award,
  ArrowUpRight,
  Clock,
  CheckCircle,
} from 'lucide-react';

export default function SalesmanDashboardPage() {
  const { data: performance, isLoading } = useQuery({
    queryKey: ['salesman-performance'],
    queryFn: () => api.get('/salesmen/my-performance'),
  });

  const salesman = (performance as any)?.salesman || {};
  const metrics = (performance as any)?.metrics || {};
  const incentives = metrics.incentives || {};

  if (isLoading) {
    return (
      <div className="flex items-center justify-center min-h-[60vh]">
        <div className="text-center space-y-3">
          <div className="w-10 h-10 border-4 border-teal-600 border-t-transparent rounded-full animate-spin mx-auto"></div>
          <p className="text-sm font-medium text-slate-500">Loading your sales performance data...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Salesman Header Banner */}
      <div className="bg-gradient-to-r from-teal-700 via-teal-800 to-slate-900 rounded-3xl p-6 lg:p-8 text-white relative overflow-hidden shadow-xl shadow-teal-900/10">
        <div className="relative z-10 flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
          <div>
            <span className="px-3 py-1 bg-white/10 backdrop-blur-md rounded-full text-xs font-semibold uppercase tracking-wider text-teal-200 border border-white/15">
              Assigned Territory: {salesman.territory || 'North Region'}
            </span>
            <h1 className="text-2xl lg:text-3xl font-black mt-3">Welcome, {salesman.name}!</h1>
            <p className="text-xs text-teal-100 max-w-xl mt-1">
              Track your field dealer pipeline, generate commercial quotations, and maximize your provisional incentives.
            </p>
          </div>

          <div className="bg-white/10 backdrop-blur-md rounded-2xl p-4 border border-white/20 text-center min-w-[200px]">
            <span className="text-[11px] uppercase font-bold text-teal-200">Monthly Target Progress</span>
            <div className="text-2xl font-black text-white mt-1">
              {metrics.targetAchievementPercent || 0}%
            </div>
            <div className="w-full bg-white/20 h-2 rounded-full mt-2 overflow-hidden">
              <div
                className="bg-emerald-400 h-full rounded-full transition-all"
                style={{ width: `${Math.min(100, metrics.targetAchievementPercent || 0)}%` }}
              ></div>
            </div>
            <span className="text-[10px] text-teal-200 mt-1 block">
              ₹{Number(metrics.totalSalesValue || 0).toLocaleString('en-IN')} / ₹{Number(salesman.monthlyTarget || 0).toLocaleString('en-IN')}
            </span>
          </div>
        </div>
      </div>

      {/* Metric Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Assigned Shops</span>
            <div className="p-2 bg-teal-50 text-teal-600 rounded-xl">
              <Store className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 mt-3">{metrics.assignedShopsCount || 0} Accounts</div>
          <p className="text-xs text-slate-500 font-medium mt-1">Dealers, Wholesalers & Distributors</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Conversion Rate</span>
            <div className="p-2 bg-sky-50 text-sky-600 rounded-xl">
              <TrendingUp className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-sky-700 mt-3">{metrics.conversionRate || 0}%</div>
          <p className="text-xs text-slate-500 font-medium mt-1">
            {metrics.acceptedQuotations || 0} accepted of {metrics.totalQuotations || 0} quotations
          </p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Total Net Sales</span>
            <div className="p-2 bg-emerald-50 text-emerald-600 rounded-xl">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-emerald-700 mt-3 font-mono">
            ₹{Number(metrics.totalSalesValue || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </div>
          <p className="text-xs text-slate-500 font-medium mt-1">{metrics.totalOrdersCount || 0} generated orders</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">Incentives Earned</span>
            <div className="p-2 bg-amber-50 text-amber-600 rounded-xl">
              <Award className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-amber-600 mt-3 font-mono">
            ₹{Number(incentives.totalEarned || 0).toLocaleString('en-IN')}
          </div>
          <p className="text-xs text-slate-500 font-medium mt-1">
            ₹{Number(incentives.paid || 0).toLocaleString('en-IN')} paid • ₹{Number(incentives.pending || 0).toLocaleString('en-IN')} pending
          </p>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white p-6 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <h2 className="text-base font-bold text-slate-900">Field Workflow Quick Links</h2>
        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
          <a
            href="/dashboard/quotations"
            className="p-4 bg-teal-50 hover:bg-teal-100/70 border border-teal-200 rounded-2xl flex items-center justify-between transition-all group"
          >
            <div>
              <h3 className="font-bold text-teal-950 text-sm">Create New Quotation</h3>
              <p className="text-xs text-teal-700 mt-0.5">Prepare proposal with buyer tier pricing</p>
            </div>
            <ArrowUpRight className="w-5 h-5 text-teal-600 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
          </a>

          <a
            href="/dashboard/shops"
            className="p-4 bg-sky-50 hover:bg-sky-100/70 border border-sky-200 rounded-2xl flex items-center justify-between transition-all group"
          >
            <div>
              <h3 className="font-bold text-sky-950 text-sm">Assigned Shops</h3>
              <p className="text-xs text-sky-700 mt-0.5">View buyer credit, ledger, and terms</p>
            </div>
            <ArrowUpRight className="w-5 h-5 text-sky-600 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
          </a>

          <a
            href="/dashboard/incentives"
            className="p-4 bg-emerald-50 hover:bg-emerald-100/70 border border-emerald-200 rounded-2xl flex items-center justify-between transition-all group"
          >
            <div>
              <h3 className="font-bold text-emerald-950 text-sm">Incentive Ledger</h3>
              <p className="text-xs text-emerald-700 mt-0.5">Delivered orders commission report</p>
            </div>
            <ArrowUpRight className="w-5 h-5 text-emerald-600 group-hover:translate-x-1 group-hover:-translate-y-1 transition-transform" />
          </a>
        </div>
      </div>
    </div>
  );
}
