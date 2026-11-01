'use client';

import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { TrendingUp, Award, CheckCircle, Clock } from 'lucide-react';

export default function SalesmanIncentivesPage() {
  const { data: incentives, isLoading } = useQuery({
    queryKey: ['my-incentive-ledger'],
    queryFn: () => api.get('/salesmen/my-incentives'),
  });

  const list = (incentives as any) || [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">My Incentive Ledger</h1>
          <p className="text-sm text-slate-500">
            Transparent commission statements generated from delivered water purifier orders in your territory.
          </p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Date</th>
                <th className="px-5 py-3.5">Eligible Sales Basis</th>
                <th className="px-5 py-3.5">Rate %</th>
                <th className="px-5 py-3.5">Calculated Amount</th>
                <th className="px-5 py-3.5">Approved Amount</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Remarks</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">Loading commission ledger...</td>
                </tr>
              ) : list.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">
                    No incentive entries yet. Deliver orders to generate provisional commission!
                  </td>
                </tr>
              ) : (
                list.map((inc: any) => (
                  <tr key={inc.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-3.5 text-slate-500 font-mono">
                      {new Date(inc.createdAt).toLocaleDateString()}
                    </td>
                    <td className="px-5 py-3.5 font-mono font-bold text-slate-900">
                      ₹{Number(inc.eligibleSales).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>
                    <td className="px-5 py-3.5 font-mono text-teal-700 font-bold">{inc.incentiveRate}%</td>
                    <td className="px-5 py-3.5 font-mono font-bold text-amber-600">
                      ₹{Number(inc.calculatedAmount).toLocaleString('en-IN')}
                    </td>
                    <td className="px-5 py-3.5 font-mono font-bold text-emerald-600">
                      ₹{Number(inc.approvedAmount).toLocaleString('en-IN')}
                    </td>
                    <td className="px-5 py-3.5">
                      <span
                        className={`px-2.5 py-1 rounded-full text-[10px] font-bold uppercase ${
                          inc.status === 'PAID'
                            ? 'bg-emerald-100 text-emerald-800'
                            : inc.status === 'APPROVED'
                            ? 'bg-sky-100 text-sky-800'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {inc.status}
                      </span>
                    </td>
                    <td className="px-5 py-3.5 text-slate-500 text-[11px]">{inc.remarks || '-'}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
