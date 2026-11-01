'use client';

import React, { useState, useMemo } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  CreditCard,
  Search,
  CheckCircle,
  AlertTriangle,
  Clock,
  TrendingUp,
  DollarSign,
  Edit2,
  X,
  Calendar,
  Sparkles,
} from 'lucide-react';

const PRESET_PAYMENT_CYCLES = [
  { days: 7, label: '7 Days (Dealers)' },
  { days: 15, label: '15 Days (Wholesalers)' },
  { days: 30, label: '30 Days (Distributors)' },
  { days: 45, label: '45 Days (Key Accounts)' },
  { days: 60, label: '60 Days (Extended)' },
  { days: 90, label: '90 Days (Quarterly)' },
];

export default function CreditManagementPage() {
  const queryClient = useQueryClient();
  const [selectedAccount, setSelectedAccount] = useState<any>(null);
  const [newLimit, setNewLimit] = useState<number>(0);
  const [paymentTermsDays, setPaymentTermsDays] = useState<number>(15);
  const [reason, setReason] = useState<string>('');

  // Search & Filter state
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [categoryFilter, setCategoryFilter] = useState<string>('ALL');
  const [exposureFilter, setExposureFilter] = useState<string>('ALL');

  const { data: accounts, isLoading } = useQuery({
    queryKey: ['credit-accounts'],
    queryFn: () => api.get('/credit/accounts'),
  });

  const creditAccounts: any[] = useMemo(() => {
    return Array.isArray(accounts) ? accounts : [];
  }, [accounts]);

  // Overall dynamic portfolio calculations
  const portfolioStats = useMemo(() => {
    const totalLimit = creditAccounts.reduce((acc, curr) => acc + (Number(curr.creditLimit) || 0), 0);
    const totalUtilized = creditAccounts.reduce((acc, curr) => acc + (Number(curr.utilizedCredit) || 0), 0);
    const totalAvailable = creditAccounts.reduce((acc, curr) => acc + (Number(curr.availableCredit) || 0), 0);
    const highExposureCount = creditAccounts.filter((acc) => {
      const limit = Number(acc.creditLimit) || 0;
      const util = Number(acc.utilizedCredit) || 0;
      return limit > 0 && util / limit >= 0.8;
    }).length;
    const avgCycle = creditAccounts.length
      ? Math.round(creditAccounts.reduce((acc, curr) => acc + (Number(curr.paymentTermsDays) || 15), 0) / creditAccounts.length)
      : 15;

    return {
      totalLimit,
      totalUtilized,
      totalAvailable,
      highExposureCount,
      avgCycle,
      overallUtilizationPercent: totalLimit > 0 ? (totalUtilized / totalLimit) * 100 : 0,
    };
  }, [creditAccounts]);

  // Filtered accounts
  const filteredAccounts = useMemo(() => {
    return creditAccounts.filter((acc) => {
      const buyer = acc.buyer || {};
      const businessName = (buyer.businessName || '').toLowerCase();
      const fullName = (buyer.user?.fullName || '').toLowerCase();
      const buyerId = (buyer.buyerId || '').toLowerCase();
      const q = searchQuery.toLowerCase();

      const matchesSearch = !searchQuery || businessName.includes(q) || fullName.includes(q) || buyerId.includes(q);

      const buyerType = buyer.buyerType || 'CUSTOMER';
      const matchesCategory = categoryFilter === 'ALL' || buyerType === categoryFilter;

      const limit = Number(acc.creditLimit) || 0;
      const utilized = Number(acc.utilizedCredit) || 0;
      const ratio = limit > 0 ? utilized / limit : 0;

      let matchesExposure = true;
      if (exposureFilter === 'HIGH') matchesExposure = ratio >= 0.8;
      else if (exposureFilter === 'MODERATE') matchesExposure = ratio >= 0.4 && ratio < 0.8;
      else if (exposureFilter === 'LOW') matchesExposure = ratio < 0.4;

      return matchesSearch && matchesCategory && matchesExposure;
    });
  }, [creditAccounts, searchQuery, categoryFilter, exposureFilter]);

  const updateLimitMutation = useMutation({
    mutationFn: (vars: { buyerProfileId: string; creditLimit: number; paymentTermsDays: number; reason: string }) =>
      api.put(`/credit/buyer/${vars.buyerProfileId}/limit`, {
        creditLimit: vars.creditLimit,
        paymentTermsDays: vars.paymentTermsDays,
        reason: vars.reason,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['credit-accounts'] });
      setSelectedAccount(null);
      setReason('');
      alert('Credit facility and payment terms updated successfully with audit trail.');
    },
    onError: (err: any) => alert(`Error: ${err.message}`),
  });

  const handleOpenAdjust = (acc: any) => {
    setSelectedAccount(acc);
    setNewLimit(Number(acc.creditLimit) || 0);
    setPaymentTermsDays(Number(acc.paymentTermsDays) || 15);
    setReason('');
  };

  // Dynamic calculations for selected account in modal
  const currentLimit = selectedAccount ? Number(selectedAccount.creditLimit) || 0 : 0;
  const currentUtilized = selectedAccount ? Number(selectedAccount.utilizedCredit) || 0 : 0;
  const currentAvailable = selectedAccount ? Number(selectedAccount.availableCredit) || 0 : 0;
  const limitDifference = newLimit - currentLimit;
  const projectedAvailable = Math.max(0, newLimit - currentUtilized);
  const isOverUtilizedWithNewLimit = newLimit > 0 && newLimit < currentUtilized;
  const projectedUtilizationPercent = newLimit > 0 ? Math.min(100, (currentUtilized / newLimit) * 100) : 0;

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <CreditCard className="w-6 h-6 text-sky-600" />
            <h1 className="text-2xl font-black text-slate-900 tracking-tight">Credit Management</h1>
          </div>
          <p className="text-sm text-slate-500 mt-1">
            Real-time approved credit limits, live utilized balances, custom payment term cycles, and risk exposure monitoring.
          </p>
        </div>
      </div>

      {/* Dynamic Summary Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Total Approved Credit</span>
            <div className="p-2 bg-sky-50 rounded-xl text-sky-600">
              <DollarSign className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-slate-900 mt-2 font-mono">
            ₹{portfolioStats.totalLimit.toLocaleString('en-IN')}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Across {creditAccounts.length} commercial buyer facilities
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Credit Used Now</span>
            <div className="p-2 bg-amber-50 rounded-xl text-amber-600">
              <TrendingUp className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-amber-600 mt-2 font-mono">
            ₹{portfolioStats.totalUtilized.toLocaleString('en-IN')}
          </div>
          <div className="flex items-center gap-2 mt-1">
            <div className="w-20 bg-slate-100 rounded-full h-1.5 overflow-hidden">
              <div
                className="bg-amber-500 h-1.5 rounded-full"
                style={{ width: `${Math.min(100, portfolioStats.overallUtilizationPercent)}%` }}
              />
            </div>
            <span className="text-[11px] font-bold text-slate-500">
              {portfolioStats.overallUtilizationPercent.toFixed(1)}% utilized
            </span>
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Available Balance</span>
            <div className="p-2 bg-emerald-50 rounded-xl text-emerald-600">
              <CheckCircle className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-emerald-600 mt-2 font-mono">
            ₹{portfolioStats.totalAvailable.toLocaleString('en-IN')}
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            Healthy trade buffer available for orders
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-sm">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-500 uppercase tracking-wider">Avg Payment Cycle</span>
            <div className="p-2 bg-indigo-50 rounded-xl text-indigo-600">
              <Clock className="w-5 h-5" />
            </div>
          </div>
          <div className="text-2xl font-black text-indigo-700 mt-2">
            {portfolioStats.avgCycle} <span className="text-sm font-semibold text-slate-500">Days Net</span>
          </div>
          <div className="text-[11px] text-slate-400 mt-1">
            {portfolioStats.highExposureCount > 0 ? (
              <span className="text-red-500 font-bold flex items-center gap-1">
                <AlertTriangle className="w-3 h-3" /> {portfolioStats.highExposureCount} accounts &gt;80% utilized
              </span>
            ) : (
              'All credit lines within safe limits'
            )}
          </div>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-center justify-between gap-3">
        <div className="relative w-full md:w-80">
          <Search className="absolute left-3 top-2.5 w-4 h-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search buyer name, code, contact..."
            className="w-full pl-9 pr-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-sky-500"
          />
        </div>

        <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
          {/* Category Filter */}
          <div className="flex items-center gap-1 bg-slate-50 p-1 rounded-xl border border-slate-200">
            {['ALL', 'DISTRIBUTOR', 'WHOLESALER', 'DEALER', 'CUSTOMER'].map((cat) => (
              <button
                key={cat}
                onClick={() => setCategoryFilter(cat)}
                className={`px-2.5 py-1 text-[11px] font-bold rounded-lg transition-colors ${
                  categoryFilter === cat
                    ? 'bg-white text-sky-600 shadow-sm border border-slate-200'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                {cat}
              </button>
            ))}
          </div>

          {/* Exposure Filter */}
          <select
            value={exposureFilter}
            onChange={(e) => setExposureFilter(e.target.value)}
            className="px-3 py-1.5 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-700 focus:outline-none"
          >
            <option value="ALL">All Exposure Levels</option>
            <option value="HIGH">High Risk (&ge;80% used)</option>
            <option value="MODERATE">Moderate (40-80% used)</option>
            <option value="LOW">Low (&lt;40% used)</option>
          </select>
        </div>
      </div>

      {/* Credit Accounts Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Buyer</th>
                <th className="px-5 py-3.5">Category</th>
                <th className="px-5 py-3.5">Current Credit Limit</th>
                <th className="px-5 py-3.5">Credit Used Now</th>
                <th className="px-5 py-3.5">Available Balance</th>
                <th className="px-5 py-3.5">Payment Term Cycle</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">
                    Loading commercial credit facilities...
                  </td>
                </tr>
              ) : filteredAccounts.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">
                    No credit accounts matching your query.
                  </td>
                </tr>
              ) : (
                filteredAccounts.map((acc: any) => {
                  const limit = Number(acc.creditLimit) || 0;
                  const utilized = Number(acc.utilizedCredit) || 0;
                  const available = Number(acc.availableCredit) || 0;
                  const percentUsed = limit > 0 ? (utilized / limit) * 100 : 0;

                  return (
                    <tr key={acc.id} className="hover:bg-slate-50/80 transition-colors">
                      <td className="px-5 py-3.5">
                        <div className="font-bold text-slate-900 text-sm">
                          {acc.buyer?.businessName || acc.buyer?.user?.fullName || 'Commercial Buyer'}
                        </div>
                        <div className="flex items-center gap-2 mt-0.5">
                          <span className="text-[11px] text-sky-700 font-mono font-bold">{acc.buyer?.buyerId || 'BUY-ID'}</span>
                          <span className="text-[11px] text-slate-400">· {acc.buyer?.user?.fullName}</span>
                          {acc.buyer?.user?.phone && (
                            <span className="text-[10px] text-slate-400 font-mono">({acc.buyer?.user?.phone})</span>
                          )}
                        </div>
                      </td>

                      <td className="px-5 py-3.5">
                        <span className="px-2.5 py-1 bg-slate-100 text-slate-700 font-bold rounded-lg text-[10px] uppercase">
                          {acc.buyer?.buyerType || 'CUSTOMER'}
                        </span>
                      </td>

                      <td className="px-5 py-3.5 font-mono font-bold text-slate-900 text-sm">
                        ₹{limit.toLocaleString('en-IN')}
                      </td>

                      <td className="px-5 py-3.5">
                        <div className="font-mono font-bold text-amber-600 text-sm">
                          ₹{utilized.toLocaleString('en-IN')}
                        </div>
                        <div className="flex items-center gap-2 mt-1">
                          <div className="w-16 bg-slate-100 rounded-full h-1.5 overflow-hidden">
                            <div
                              className={`h-1.5 rounded-full ${
                                percentUsed >= 80 ? 'bg-red-500' : percentUsed >= 50 ? 'bg-amber-500' : 'bg-emerald-500'
                              }`}
                              style={{ width: `${Math.min(100, percentUsed)}%` }}
                            />
                          </div>
                          <span className="text-[10px] font-bold text-slate-500">
                            {percentUsed.toFixed(0)}% used
                          </span>
                        </div>
                      </td>

                      <td className="px-5 py-3.5">
                        <div className="font-mono font-bold text-emerald-600 text-sm">
                          ₹{available.toLocaleString('en-IN')}
                        </div>
                        <span className="text-[10px] text-emerald-700 font-medium">Ready for Orders</span>
                      </td>

                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-1.5">
                          <Clock className="w-3.5 h-3.5 text-sky-600" />
                          <span className="font-bold text-slate-800 text-xs">
                            {acc.paymentTermsDays || 15} Days Net
                          </span>
                        </div>
                        <span className="text-[10px] text-slate-400">Invoice payment cycle</span>
                      </td>

                      <td className="px-5 py-3.5 text-right">
                        <button
                          onClick={() => handleOpenAdjust(acc)}
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-sky-50 text-sky-700 hover:bg-sky-100 font-bold rounded-xl transition-all shadow-sm active:scale-95"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                          <span>Adjust Terms</span>
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Adjust Credit Modal */}
      {selectedAccount && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 space-y-5 my-8">
            {/* Modal Header */}
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-lg font-black text-slate-900 tracking-tight flex items-center gap-2">
                  <CreditCard className="w-5 h-5 text-sky-600" />
                  Adjust Credit Facility & Terms
                </h2>
                <div className="flex items-center gap-2 mt-0.5">
                  <span className="text-xs font-bold text-slate-800">
                    {selectedAccount.buyer?.businessName || selectedAccount.buyer?.user?.fullName}
                  </span>
                  <span className="text-[10px] font-mono text-sky-700 bg-sky-50 px-2 py-0.5 rounded font-bold">
                    {selectedAccount.buyer?.buyerId || 'BUY-ID'}
                  </span>
                </div>
              </div>
              <button
                onClick={() => setSelectedAccount(null)}
                className="text-slate-400 hover:text-slate-600 p-1.5 hover:bg-slate-100 rounded-xl"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Dynamic Live Status Card */}
            <div className="bg-slate-50 border border-slate-200/80 rounded-2xl p-4 space-y-3">
              <div className="text-[11px] font-bold text-slate-500 uppercase tracking-wider flex items-center gap-1">
                <Sparkles className="w-3.5 h-3.5 text-sky-600" /> Current Standing & Live Utilization
              </div>
              <div className="grid grid-cols-3 gap-2 text-center">
                <div className="bg-white p-2.5 rounded-xl border border-slate-200">
                  <div className="text-[10px] text-slate-500 font-bold uppercase">Current Limit</div>
                  <div className="text-sm font-black font-mono text-slate-800 mt-0.5">
                    ₹{currentLimit.toLocaleString('en-IN')}
                  </div>
                </div>

                <div className="bg-white p-2.5 rounded-xl border border-slate-200">
                  <div className="text-[10px] text-slate-500 font-bold uppercase">Credit Used Now</div>
                  <div className="text-sm font-black font-mono text-amber-600 mt-0.5">
                    ₹{currentUtilized.toLocaleString('en-IN')}
                  </div>
                  <div className="text-[9px] font-bold text-slate-400">
                    {currentLimit > 0 ? `${((currentUtilized / currentLimit) * 100).toFixed(0)}% used` : '0%'}
                  </div>
                </div>

                <div className="bg-white p-2.5 rounded-xl border border-slate-200">
                  <div className="text-[10px] text-slate-500 font-bold uppercase">Available Balance</div>
                  <div className="text-sm font-black font-mono text-emerald-600 mt-0.5">
                    ₹{currentAvailable.toLocaleString('en-IN')}
                  </div>
                </div>
              </div>
            </div>

            <div className="space-y-4">
              {/* Approved Credit Limit Input & Real-Time Calculation */}
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">
                  New Approved Credit Limit (INR) *
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-400 font-bold font-mono text-xs">₹</span>
                  <input
                    type="number"
                    min="0"
                    step="5000"
                    required
                    value={newLimit}
                    onChange={(e) => setNewLimit(Number(e.target.value) || 0)}
                    placeholder="Enter limit in ₹..."
                    className="w-full pl-7 pr-3 py-2 bg-white border border-slate-300 rounded-xl text-xs font-mono font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                {/* Real-Time Limit Difference & Projected Available Balance */}
                <div className="mt-2 p-2.5 bg-sky-50/70 border border-sky-100 rounded-xl space-y-1 text-xs">
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600 font-medium">Limit Variance:</span>
                    <span
                      className={`font-mono font-bold ${
                        limitDifference > 0
                          ? 'text-emerald-600'
                          : limitDifference < 0
                          ? 'text-amber-600'
                          : 'text-slate-600'
                      }`}
                    >
                      {limitDifference > 0 ? `+₹${limitDifference.toLocaleString('en-IN')} (Increase)` : limitDifference < 0 ? `-₹${Math.abs(limitDifference).toLocaleString('en-IN')} (Reduction)` : 'No change'}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600 font-medium">New Available Balance:</span>
                    <span className="font-mono font-bold text-emerald-700">
                      ₹{projectedAvailable.toLocaleString('en-IN')}
                    </span>
                  </div>
                  <div className="flex items-center justify-between">
                    <span className="text-slate-600 font-medium">Projected Utilization:</span>
                    <span className="font-mono font-bold text-slate-700">
                      {projectedUtilizationPercent.toFixed(1)}%
                    </span>
                  </div>
                </div>

                {/* Over-utilization Warning if new limit < credit used */}
                {isOverUtilizedWithNewLimit && (
                  <div className="mt-2 p-2.5 bg-red-50 border border-red-200 rounded-xl flex items-start gap-2 text-xs text-red-700">
                    <AlertTriangle className="w-4 h-4 flex-shrink-0 text-red-600 mt-0.5" />
                    <div>
                      <span className="font-bold">Over-utilization Warning:</span> The proposed limit of ₹
                      {newLimit.toLocaleString('en-IN')} is lower than currently utilized credit of ₹
                      {currentUtilized.toLocaleString('en-IN')}. The buyer will have an excess exposure of ₹
                      {(currentUtilized - newLimit).toLocaleString('en-IN')}.
                    </div>
                  </div>
                )}
              </div>

              {/* Payment Term Cycle (Days) - CUSTOM TYPING & PRESET CHIPS */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="text-xs font-bold text-slate-700">
                    Payment Term Cycle (Days) *
                  </label>
                  <span className="text-[11px] text-sky-700 font-bold">
                    Custom typing enabled
                  </span>
                </div>

                {/* Custom Typing Number Input */}
                <div className="relative">
                  <input
                    type="number"
                    min="1"
                    max="365"
                    required
                    value={paymentTermsDays}
                    onChange={(e) => setPaymentTermsDays(Math.max(1, parseInt(e.target.value) || 1))}
                    placeholder="Type custom days (e.g. 7, 15, 21, 30, 45, 60)..."
                    className="w-full px-3 py-2 bg-white border border-slate-300 rounded-xl text-xs font-bold font-mono text-slate-900 focus:outline-none focus:ring-2 focus:ring-sky-500 pr-16"
                  />
                  <div className="absolute right-3 top-2 text-xs font-bold text-slate-400 pointer-events-none">
                    Days Net
                  </div>
                </div>

                {/* Quick Presets Selection Chips */}
                <div className="mt-2">
                  <div className="text-[10px] font-bold text-slate-400 uppercase tracking-wider mb-1">
                    Quick Preset Cycles (Click to Auto-fill)
                  </div>
                  <div className="grid grid-cols-3 gap-1.5">
                    {PRESET_PAYMENT_CYCLES.map((p) => {
                      const isSelected = paymentTermsDays === p.days;
                      return (
                        <button
                          key={p.days}
                          type="button"
                          onClick={() => setPaymentTermsDays(p.days)}
                          className={`px-2 py-1.5 rounded-lg text-[11px] font-bold text-center border transition-all ${
                            isSelected
                              ? 'bg-sky-600 text-white border-sky-600 shadow-sm'
                              : 'bg-slate-50 text-slate-700 border-slate-200 hover:bg-slate-100 hover:border-slate-300'
                          }`}
                        >
                          {p.label}
                        </button>
                      );
                    })}
                  </div>
                </div>

                {/* Dynamic Cycle Explainer */}
                <div className="mt-2 flex items-center gap-1.5 text-[11px] text-slate-500 bg-slate-50 p-2 rounded-xl border border-slate-100">
                  <Calendar className="w-3.5 h-3.5 text-sky-600 flex-shrink-0" />
                  <span>
                    Buyer will receive a payment grace period of <strong className="text-slate-800">{paymentTermsDays} days</strong> from invoice dispatch date before overdue status.
                  </span>
                </div>
              </div>

              {/* Reason / Board Authorization */}
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1.5">
                  Adjustment Reason / Audit Trail *
                </label>
                <input
                  type="text"
                  required
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  placeholder="e.g. Approved quarterly enhancement based on healthy repayment track record..."
                  className="w-full px-3 py-2 bg-white border border-slate-300 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 text-slate-800"
                />
              </div>
            </div>

            {/* Action Buttons */}
            <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setSelectedAccount(null)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!reason.trim() || newLimit < 0 || paymentTermsDays <= 0 || updateLimitMutation.isPending}
                onClick={() =>
                  updateLimitMutation.mutate({
                    buyerProfileId: selectedAccount.buyerProfileId || selectedAccount.buyer?.id,
                    creditLimit: newLimit,
                    paymentTermsDays,
                    reason,
                  })
                }
                className="px-5 py-2.5 bg-sky-600 hover:bg-sky-700 active:scale-95 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50 transition-all flex items-center gap-2"
              >
                {updateLimitMutation.isPending ? (
                  'Saving Changes...'
                ) : (
                  <>
                    <CheckCircle className="w-4 h-4" />
                    <span>Confirm & Update Limit</span>
                  </>
                )}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
