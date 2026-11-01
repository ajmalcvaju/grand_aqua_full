'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { Store, Search, Award, CreditCard, Clock, Phone, MapPin, Eye, FileText } from 'lucide-react';
import Link from 'next/link';

export default function AssignedShopsPage() {
  const [search, setSearch] = useState('');

  const { data, isLoading } = useQuery({
    queryKey: ['my-assigned-shops', search],
    queryFn: () => api.get(`/buyers?search=${encodeURIComponent(search)}`),
  });

  const buyers = (data as any)?.buyers || [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">My Assigned Shops & Buyers</h1>
          <p className="text-sm text-slate-500">
            Field portfolio of authorized retail dealers, wholesalers, and distributors in your territory.
          </p>
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search assigned shop..."
            className="w-full pl-9 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-teal-500"
          />
        </div>
      </div>

      {/* Shops Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="col-span-full py-12 text-center text-slate-400">Loading assigned portfolio...</div>
        ) : buyers.length === 0 ? (
          <div className="col-span-full py-12 text-center text-slate-400">No assigned shops found.</div>
        ) : (
          buyers.map((buyer: any) => (
            <div
              key={buyer.id}
              className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4 hover:shadow-md transition-shadow"
            >
              <div className="flex items-start justify-between">
                <div>
                  <span className="font-mono text-xs text-teal-600 font-bold">{buyer.buyerId}</span>
                  <h3 className="font-bold text-slate-900 text-base mt-1">
                    {buyer.businessName || buyer.user?.fullName}
                  </h3>
                  <p className="text-xs text-slate-500">{buyer.businessType || 'Retail Shop'}</p>
                </div>
                <span className="px-2.5 py-1 bg-teal-50 text-teal-800 font-bold text-[11px] rounded-full uppercase">
                  {buyer.buyerType}
                </span>
              </div>

              <div className="space-y-1.5 text-xs text-slate-600">
                <div className="flex items-center gap-2">
                  <Phone className="w-3.5 h-3.5 text-slate-400" />
                  <span>{buyer.user?.phone || 'No phone recorded'}</span>
                </div>
                <div className="flex items-center gap-2">
                  <MapPin className="w-3.5 h-3.5 text-slate-400" />
                  <span>{buyer.district ? `${buyer.district}, ${buyer.state}` : 'Local Region'}</span>
                </div>
              </div>

              <div className="p-3 bg-slate-50 rounded-xl space-y-1 text-xs font-mono">
                <div className="flex justify-between text-slate-500">
                  <span>Loyalty Tier:</span>
                  <span className="font-bold text-sky-700">{buyer.loyaltyTier}</span>
                </div>
                <div className="flex justify-between text-slate-500">
                  <span>Credit Limit:</span>
                  <span className="font-bold text-emerald-700">₹{Number(buyer.creditLimit).toLocaleString('en-IN')}</span>
                </div>
                <div className="flex justify-between text-slate-500">
                  <span>Outstanding Bal:</span>
                  <span className="font-bold text-amber-600">₹{Number(buyer.outstandingBalance).toLocaleString('en-IN')}</span>
                </div>
                <div className="flex justify-between text-slate-500 border-t border-slate-200 pt-1">
                  <span>Terms:</span>
                  <span className="font-sans font-semibold text-slate-800">{buyer.paymentTerms || 'Immediate'}</span>
                </div>
              </div>

              <div className="pt-2 border-t border-slate-100 flex items-center justify-between">
                <Link
                  href={`/dashboard/quotations?buyerId=${buyer.id}`}
                  className="w-full py-2 bg-teal-50 hover:bg-teal-100 text-teal-800 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-colors"
                >
                  <FileText className="w-3.5 h-3.5" />
                  <span>Create Quotation</span>
                </Link>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
