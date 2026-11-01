'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { Package, Search, Droplet, CheckCircle, Info } from 'lucide-react';

export default function SalesmanProductsPage() {
  const [search, setSearch] = useState('');
  const [selectedBuyerType, setSelectedBuyerType] = useState('DEALER');

  const { data, isLoading } = useQuery({
    queryKey: ['salesman-products', search, selectedBuyerType],
    queryFn: () => api.get(`/products?search=${encodeURIComponent(search)}&buyerType=${selectedBuyerType}`),
  });

  const products = (data as any)?.products || [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Product Catalogue</h1>
          <p className="text-sm text-slate-500">
            View technical specifications, inventory availability, and category-calculated trade prices.
          </p>
        </div>

        {/* Selected Buyer Category Filter */}
        <div className="flex items-center gap-2 bg-white p-2 rounded-xl border border-slate-200 shadow-sm text-xs">
          <span className="font-bold text-slate-500">Show Price For:</span>
          <select
            value={selectedBuyerType}
            onChange={(e) => setSelectedBuyerType(e.target.value)}
            className="px-2 py-1 bg-slate-50 border border-slate-200 rounded-lg font-bold text-teal-800 focus:outline-none"
          >
            <option value="DISTRIBUTOR">Distributor Price</option>
            <option value="WHOLESALER">Wholesaler Price</option>
            <option value="DEALER">Dealer / Retailer Price</option>
            <option value="CUSTOMER">Retail Customer Price</option>
          </select>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="col-span-full py-12 text-center text-slate-400">Loading products...</div>
        ) : (
          products.map((prod: any) => (
            <div key={prod.id} className="bg-white rounded-2xl border border-slate-200 p-5 shadow-sm space-y-3">
              <div className="h-40 bg-slate-100 rounded-xl overflow-hidden relative flex items-center justify-center">
                {prod.media?.[0]?.url ? (
                  <img src={prod.media[0].url} alt={prod.name} className="w-full h-full object-cover" />
                ) : (
                  <Droplet className="w-10 h-10 text-teal-400 opacity-60" />
                )}
                <span className="absolute top-2.5 left-2.5 px-2 py-0.5 bg-slate-900/80 backdrop-blur-sm text-white font-mono text-[10px] font-bold rounded-md">
                  {prod.sku}
                </span>
              </div>

              <div>
                <span className="text-[10px] uppercase font-bold text-teal-600">{prod.category?.name}</span>
                <h3 className="font-bold text-slate-900 text-sm mt-0.5">{prod.name}</h3>
                <p className="text-xs text-slate-500 line-clamp-2 mt-1">{prod.shortDescription}</p>
              </div>

              <div className="p-3 bg-teal-50/70 border border-teal-100 rounded-xl flex items-center justify-between">
                <div>
                  <span className="text-[10px] text-teal-800 font-bold uppercase">{selectedBuyerType} Rate:</span>
                  <div className="text-lg font-black text-teal-900 font-mono">
                    ₹{Number(prod.applicablePrice || 0).toLocaleString('en-IN')}
                  </div>
                </div>
                <span className="text-xs text-slate-400">+ 18% GST</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}
