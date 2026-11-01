'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Search,
  Users,
  TrendingUp,
  Clock,
  Sparkles,
  ChevronRight,
  Filter,
  BarChart3,
  Calendar,
  Phone,
  Mail,
  RefreshCw,
  Hash,
  AlertCircle,
  Flame,
} from 'lucide-react';

interface BuyerSearchSummary {
  id: string;
  buyerId: string;
  businessName: string;
  buyerType: string;
  fullName: string;
  phone: string;
  email: string;
  totalSearches: number;
  uniqueKeywordsCount: number;
  lastSearchedAt: string;
  topKeywords: Array<{ keyword: string; count: number }>;
}

interface BuyerKeywordDetail {
  id: string;
  keyword: string;
  searchCount: number;
  lastSearchedAt: string;
  createdAt: string;
}

export default function SearchKeywordsPage() {
  const [buyerFilter, setBuyerFilter] = useState('');
  const [selectedBuyerType, setSelectedBuyerType] = useState('ALL');
  const [selectedBuyerId, setSelectedBuyerId] = useState<string | null>(null);
  const [keywordSearch, setKeywordSearch] = useState('');
  const [sortBy, setSortBy] = useState<'count' | 'recent' | 'alpha'>('count');

  // 1. Fetch buyers with searches
  const {
    data: rawBuyersData = [],
    isLoading: isLoadingBuyers,
    refetch: refetchBuyers,
    isFetching,
  } = useQuery<any>({
    queryKey: ['search-buyers'],
    queryFn: async () => {
      const res: any = await api.get('/search-analytics/buyers');
      return res;
    },
    refetchInterval: 10000,
  });

  const buyers: BuyerSearchSummary[] = Array.isArray(rawBuyersData)
    ? rawBuyersData
    : Array.isArray(rawBuyersData?.data)
    ? rawBuyersData.data
    : [];

  // Automatically select first buyer if none selected
  const activeBuyerId = selectedBuyerId || (buyers.length > 0 ? buyers[0].id : null);

  // 2. Fetch keywords for selected buyer
  const {
    data: rawBuyerDetail,
    isLoading: isLoadingDetail,
    refetch: refetchDetail,
  } = useQuery<any>({
    queryKey: ['buyer-keywords', activeBuyerId],
    queryFn: async () => {
      if (!activeBuyerId) return null;
      const res: any = await api.get(`/search-analytics/buyer/${activeBuyerId}`);
      return res;
    },
    enabled: !!activeBuyerId,
  });

  const buyerDetail: {
    buyer: any;
    totalSearches: number;
    uniqueKeywordsCount: number;
    keywords: BuyerKeywordDetail[];
  } | null = rawBuyerDetail?.buyer
    ? rawBuyerDetail
    : rawBuyerDetail?.data?.buyer
    ? rawBuyerDetail.data
    : null;

  // Filter buyers on client
  const filteredBuyers = buyers.filter((b) => {
    const matchesSearch =
      b.fullName.toLowerCase().includes(buyerFilter.toLowerCase()) ||
      b.businessName.toLowerCase().includes(buyerFilter.toLowerCase()) ||
      b.phone.toLowerCase().includes(buyerFilter.toLowerCase()) ||
      b.buyerId.toLowerCase().includes(buyerFilter.toLowerCase());

    const matchesType =
      selectedBuyerType === 'ALL' || b.buyerType === selectedBuyerType;

    return matchesSearch && matchesType;
  });

  // Overall Global Summary Stats
  const totalGlobalSearches = buyers.reduce((sum, b) => sum + b.totalSearches, 0);
  const totalUniqueBuyers = buyers.length;
  const totalUniqueKeywords = buyers.reduce((sum, b) => sum + b.uniqueKeywordsCount, 0);

  // Filter and sort keywords for selected buyer
  let displayedKeywords = [...(buyerDetail?.keywords || [])];
  if (keywordSearch.trim()) {
    const q = keywordSearch.toLowerCase().trim();
    displayedKeywords = displayedKeywords.filter((k) =>
      k.keyword.toLowerCase().includes(q)
    );
  }

  if (sortBy === 'count') {
    displayedKeywords.sort((a, b) => b.searchCount - a.searchCount);
  } else if (sortBy === 'recent') {
    displayedKeywords.sort(
      (a, b) => new Date(b.lastSearchedAt).getTime() - new Date(a.lastSearchedAt).getTime()
    );
  } else if (sortBy === 'alpha') {
    displayedKeywords.sort((a, b) => a.keyword.localeCompare(b.keyword));
  }

  const maxSearchCount = Math.max(
    ...(buyerDetail?.keywords?.map((k) => k.searchCount) || [1]),
    1
  );

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Page Title & Refresh */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2.5 bg-sky-500/10 text-sky-600 rounded-xl">
              <Search className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-black text-slate-900 tracking-tight">
                Buyer Search Keywords
              </h1>
              <p className="text-xs sm:text-sm text-slate-500">
                Track buyer search queries, intent, keyword frequency, and catalog demand
              </p>
            </div>
          </div>
        </div>

        <button
          onClick={() => {
            refetchBuyers();
            refetchDetail();
          }}
          disabled={isFetching}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-200 rounded-xl text-xs font-semibold text-slate-700 hover:bg-slate-50 transition shadow-sm"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${isFetching ? 'animate-spin text-sky-600' : ''}`} />
          Refresh Data
        </button>
      </div>

      {/* Global Stat Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-sky-50 flex items-center justify-center text-sky-600">
            <Users className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
              Active Searchers
            </p>
            <p className="text-2xl font-black text-slate-900">{totalUniqueBuyers}</p>
            <p className="text-[11px] text-slate-500">Buyers with logged searches</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-emerald-50 flex items-center justify-center text-emerald-600">
            <Flame className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
              Total Searches
            </p>
            <p className="text-2xl font-black text-slate-900">{totalGlobalSearches}</p>
            <p className="text-[11px] text-slate-500">Queries logged across catalog</p>
          </div>
        </div>

        <div className="bg-white p-4 rounded-2xl border border-slate-200/80 shadow-xs flex items-center gap-4">
          <div className="w-12 h-12 rounded-xl bg-purple-50 flex items-center justify-center text-purple-600">
            <Hash className="w-6 h-6" />
          </div>
          <div>
            <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">
              Total Terms Tracked
            </p>
            <p className="text-2xl font-black text-slate-900">{totalUniqueKeywords}</p>
            <p className="text-[11px] text-slate-500">Unique buyer-keyword entries</p>
          </div>
        </div>
      </div>

      {/* Main Two-Column Layout */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Left Column: Buyers List (5 cols) */}
        <div className="lg:col-span-5 bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden flex flex-col">
          {/* Header & Filter Controls */}
          <div className="p-4 border-b border-slate-100 space-y-3">
            <div className="flex items-center justify-between">
              <h2 className="font-bold text-sm text-slate-900 flex items-center gap-2">
                <Users className="w-4 h-4 text-sky-600" />
                Buyers with Searches ({filteredBuyers.length})
              </h2>
            </div>

            {/* Buyer Search Input */}
            <div className="relative">
              <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                type="text"
                placeholder="Search buyer name, phone, code..."
                value={buyerFilter}
                onChange={(e) => setBuyerFilter(e.target.value)}
                className="w-full pl-9 pr-3 py-2 text-xs bg-slate-50 border border-slate-200 rounded-xl focus:outline-hidden focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500 transition"
              />
            </div>

            {/* Buyer Type Pills */}
            <div className="flex items-center gap-1.5 overflow-x-auto pb-1 text-[11px]">
              {['ALL', 'CUSTOMER', 'DEALER', 'WHOLESALER', 'DISTRIBUTOR'].map((t) => (
                <button
                  key={t}
                  onClick={() => setSelectedBuyerType(t)}
                  className={`px-2.5 py-1 rounded-lg font-semibold shrink-0 transition ${
                    selectedBuyerType === t
                      ? 'bg-sky-600 text-white shadow-xs'
                      : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          {/* Buyers Scrollable List */}
          <div className="divide-y divide-slate-100 max-h-[580px] overflow-y-auto">
            {isLoadingBuyers ? (
              <div className="p-8 text-center text-xs text-slate-400">Loading buyers...</div>
            ) : filteredBuyers.length === 0 ? (
              <div className="p-8 text-center space-y-2">
                <AlertCircle className="w-8 h-8 text-slate-300 mx-auto" />
                <p className="text-xs font-semibold text-slate-600">No buyers found</p>
                <p className="text-[11px] text-slate-400">
                  No buyers have searched for keywords matching this filter
                </p>
              </div>
            ) : (
              filteredBuyers.map((b) => {
                const isSelected = b.id === activeBuyerId;
                return (
                  <div
                    key={b.id}
                    onClick={() => setSelectedBuyerId(b.id)}
                    className={`p-3.5 cursor-pointer transition flex items-center justify-between gap-3 ${
                      isSelected
                        ? 'bg-sky-50/80 border-l-4 border-sky-600'
                        : 'hover:bg-slate-50 border-l-4 border-transparent'
                    }`}
                  >
                    <div className="min-w-0 space-y-1">
                      <div className="flex items-center gap-2">
                        <p className={`text-xs font-bold truncate ${isSelected ? 'text-sky-900' : 'text-slate-800'}`}>
                          {b.businessName}
                        </p>
                        <span className="text-[10px] px-1.5 py-0.5 rounded-sm bg-slate-100 text-slate-600 font-mono font-semibold">
                          {b.buyerType}
                        </span>
                      </div>

                      <p className="text-[11px] text-slate-500 truncate flex items-center gap-1.5">
                        <span>{b.fullName}</span>
                        {b.phone && <span>• {b.phone}</span>}
                      </p>

                      {/* Top keyword chips preview */}
                      {b.topKeywords && b.topKeywords.length > 0 && (
                        <div className="flex items-center gap-1 flex-wrap pt-0.5">
                          {b.topKeywords.map((k) => (
                            <span
                              key={k.keyword}
                              className="text-[10px] px-1.5 py-0.2 bg-white border border-slate-200 text-slate-600 rounded-md font-mono"
                            >
                              "{k.keyword}" ({k.count}x)
                            </span>
                          ))}
                        </div>
                      )}
                    </div>

                    <div className="text-right shrink-0 space-y-1">
                      <div className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-sky-100 text-sky-800 text-[11px] font-bold">
                        <Flame className="w-3 h-3 text-sky-600" />
                        {b.totalSearches}
                      </div>
                      <p className="text-[10px] text-slate-400">
                        {b.uniqueKeywordsCount} words
                      </p>
                    </div>
                  </div>
                );
              })
            )}
          </div>
        </div>

        {/* Right Column: Keywords Detail for Selected Buyer (7 cols) */}
        <div className="lg:col-span-7 bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden flex flex-col">
          {isLoadingDetail ? (
            <div className="p-12 text-center text-xs text-slate-400">
              Loading keyword analytics...
            </div>
          ) : !buyerDetail ? (
            <div className="p-12 text-center space-y-3">
              <Search className="w-10 h-10 text-slate-300 mx-auto" />
              <p className="text-sm font-bold text-slate-700">Select a Buyer</p>
              <p className="text-xs text-slate-400 max-w-sm mx-auto">
                Choose a buyer from the list on the left to inspect every keyword they have searched and the number of times each keyword was queried.
              </p>
            </div>
          ) : (
            <div className="flex flex-col">
              {/* Selected Buyer Profile Banner */}
              <div className="p-5 bg-gradient-to-r from-slate-900 to-slate-800 text-white flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <h3 className="font-bold text-base text-white">
                      {buyerDetail.buyer.businessName}
                    </h3>
                    <span className="text-[10px] uppercase font-mono px-2 py-0.5 bg-sky-500/20 text-sky-300 rounded-md border border-sky-400/30">
                      {buyerDetail.buyer.buyerType}
                    </span>
                  </div>
                  <div className="flex flex-wrap items-center gap-3 text-xs text-slate-300">
                    <span>Contact: {buyerDetail.buyer.fullName}</span>
                    {buyerDetail.buyer.phone && <span>• {buyerDetail.buyer.phone}</span>}
                    {buyerDetail.buyer.buyerId && (
                      <span className="font-mono text-slate-400">({buyerDetail.buyer.buyerId})</span>
                    )}
                  </div>
                </div>

                <div className="flex items-center gap-3 shrink-0 bg-slate-800/80 p-2.5 rounded-xl border border-slate-700">
                  <div className="text-center px-2">
                    <p className="text-[10px] text-slate-400 uppercase font-bold">Total</p>
                    <p className="text-lg font-black text-sky-400">{buyerDetail.totalSearches}</p>
                  </div>
                  <div className="w-px h-8 bg-slate-700" />
                  <div className="text-center px-2">
                    <p className="text-[10px] text-slate-400 uppercase font-bold">Keywords</p>
                    <p className="text-lg font-black text-emerald-400">{buyerDetail.uniqueKeywordsCount}</p>
                  </div>
                </div>
              </div>

              {/* Keywords Filter & Sort Bar */}
              <div className="p-4 border-b border-slate-100 flex flex-col sm:flex-row sm:items-center justify-between gap-3 bg-slate-50/50">
                <div className="relative flex-1">
                  <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                  <input
                    type="text"
                    placeholder="Filter searched keywords..."
                    value={keywordSearch}
                    onChange={(e) => setKeywordSearch(e.target.value)}
                    className="w-full pl-8 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-hidden focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500"
                  />
                </div>

                <div className="flex items-center gap-2">
                  <span className="text-[11px] text-slate-500 font-medium">Sort:</span>
                  <select
                    value={sortBy}
                    onChange={(e) => setSortBy(e.target.value as any)}
                    className="text-xs bg-white border border-slate-200 rounded-lg px-2.5 py-1.5 font-semibold text-slate-700 focus:outline-hidden"
                  >
                    <option value="count">Most Searched (Count)</option>
                    <option value="recent">Most Recent</option>
                    <option value="alpha">Alphabetical (A-Z)</option>
                  </select>
                </div>
              </div>

              {/* Keywords Table */}
              <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                  <thead>
                    <tr className="border-b border-slate-200 bg-slate-50 text-[11px] font-bold text-slate-500 uppercase tracking-wider">
                      <th className="py-3 px-4 w-12 text-center">#</th>
                      <th className="py-3 px-4">Searched Keyword</th>
                      <th className="py-3 px-4 w-40">No. of Times Searched</th>
                      <th className="py-3 px-4 text-right">Last Searched</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100 text-xs">
                    {displayedKeywords.length === 0 ? (
                      <tr>
                        <td colSpan={4} className="py-10 text-center text-slate-400 text-xs">
                          No keywords match this filter
                        </td>
                      </tr>
                    ) : (
                      displayedKeywords.map((kw, index) => {
                        const relativePct = Math.round((kw.searchCount / maxSearchCount) * 100);
                        return (
                          <tr key={kw.id} className="hover:bg-slate-50/70 transition">
                            {/* Rank */}
                            <td className="py-3 px-4 text-center text-slate-400 font-mono text-[11px]">
                              {index + 1}
                            </td>

                            {/* Keyword */}
                            <td className="py-3 px-4">
                              <div className="flex items-center gap-2">
                                <span className="font-bold text-slate-900 font-mono text-sm">
                                  "{kw.keyword}"
                                </span>
                                {index === 0 && sortBy === 'count' && (
                                  <span className="inline-flex items-center gap-1 text-[10px] bg-amber-50 text-amber-700 px-1.5 py-0.5 rounded-sm font-semibold border border-amber-200">
                                    <Sparkles className="w-3 h-3 text-amber-500" />
                                    Top Query
                                  </span>
                                )}
                              </div>
                            </td>

                            {/* Number of times searched */}
                            <td className="py-3 px-4">
                              <div className="space-y-1">
                                <div className="flex items-center justify-between text-xs">
                                  <span className="font-black text-sky-700 bg-sky-50 px-2 py-0.5 rounded-md border border-sky-200">
                                    {kw.searchCount} {kw.searchCount === 1 ? 'time' : 'times'}
                                  </span>
                                  <span className="text-[10px] text-slate-400 font-mono">
                                    {relativePct}%
                                  </span>
                                </div>
                                {/* Popularity bar */}
                                <div className="w-full bg-slate-100 h-1.5 rounded-full overflow-hidden">
                                  <div
                                    className="bg-sky-500 h-full rounded-full transition-all"
                                    style={{ width: `${Math.max(relativePct, 8)}%` }}
                                  />
                                </div>
                              </div>
                            </td>

                            {/* Last Searched Timestamp */}
                            <td className="py-3 px-4 text-right text-slate-500 text-[11px] whitespace-nowrap">
                              <div className="flex items-center justify-end gap-1.5">
                                <Clock className="w-3 h-3 text-slate-400" />
                                <span>{new Date(kw.lastSearchedAt).toLocaleString()}</span>
                              </div>
                            </td>
                          </tr>
                        );
                      })
                    )}
                  </tbody>
                </table>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
