'use client';

import React, { useState, useEffect } from 'react';
import {
  Gift,
  Coins,
  Settings,
  Users,
  History,
  Plus,
  Edit2,
  Trash2,
  CheckCircle,
  XCircle,
  Clock,
  Truck,
  ArrowUpRight,
  ArrowDownRight,
  Search,
  Filter,
  RefreshCw,
  Sliders,
  AlertCircle,
  ToggleLeft,
  ToggleRight,
  Upload,
  Loader2,
  ImageIcon,
} from 'lucide-react';
import { api } from '@/lib/api';

export default function LoyaltyManagementPage() {
  const [activeTab, setActiveTab] = useState<'buyers' | 'gifts' | 'redemptions'>('buyers');
  const [loading, setLoading] = useState(true);

  // Program Config State
  const [config, setConfig] = useState({
    enabled: true,
    percentage: 0.5,
    rupeePerPoint: 1.0,
  });
  const [savingConfig, setSavingConfig] = useState(false);
  const [configMsg, setConfigMsg] = useState<string | null>(null);

  // Data States
  const [buyers, setBuyers] = useState<any[]>([]);
  const [searchBuyer, setSearchBuyer] = useState('');
  const [gifts, setGifts] = useState<any[]>([]);
  const [redemptions, setRedemptions] = useState<any[]>([]);

  // Modals State
  const [adjustModal, setAdjustModal] = useState<{
    open: boolean;
    buyer: any | null;
    type: 'CREDIT' | 'DEBIT';
    amount: string;
    reason: string;
    loading: boolean;
  }>({
    open: false,
    buyer: null,
    type: 'CREDIT',
    amount: '',
    reason: '',
    loading: false,
  });

  const [historyModal, setHistoryModal] = useState<{
    open: boolean;
    buyer: any | null;
    history: any[];
    loading: boolean;
  }>({
    open: false,
    buyer: null,
    history: [],
    loading: false,
  });

  const [giftModal, setGiftModal] = useState<{
    open: boolean;
    gift: any | null;
    title: string;
    description: string;
    pointsRequired: string;
    stockQuantity: string;
    imageUrl: string;
    isActive: boolean;
    loading: boolean;
  }>({
    open: false,
    gift: null,
    title: '',
    description: '',
    pointsRequired: '500',
    stockQuantity: '50',
    imageUrl: '/uploads/products/sample-ro.jpg',
    isActive: true,
    loading: false,
  });
  const [uploadingGiftImage, setUploadingGiftImage] = useState(false);
  const [giftUploadError, setGiftUploadError] = useState<string | null>(null);

  useEffect(() => {
    loadAllData();
  }, []);

  const loadAllData = async () => {
    setLoading(true);
    try {
      const [cfgRes, buyersRes, giftsRes, redRes]: any = await Promise.all([
        api.get('/loyalty/config'),
        api.get('/loyalty/buyers'),
        api.get('/loyalty/gifts'),
        api.get('/loyalty/redemptions'),
      ]);

      if (cfgRes) setConfig(cfgRes.data || cfgRes);
      if (buyersRes) setBuyers(Array.isArray(buyersRes) ? buyersRes : buyersRes.data || []);
      if (giftsRes) setGifts(Array.isArray(giftsRes) ? giftsRes : giftsRes.data || []);
      if (redRes) setRedemptions(Array.isArray(redRes) ? redRes : redRes.data || []);
    } catch (err: any) {
      console.error('Failed to load loyalty data:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSaveConfig = async (e: React.FormEvent) => {
    e.preventDefault();
    setSavingConfig(true);
    setConfigMsg(null);
    try {
      const res: any = await api.put('/loyalty/config', {
        enabled: config.enabled,
        percentage: Number(config.percentage),
        rupeePerPoint: Number(config.rupeePerPoint),
      });
      if (res) setConfig(res.data || res);
      setConfigMsg('Loyalty program settings updated successfully!');
      setTimeout(() => setConfigMsg(null), 3000);
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to save loyalty settings');
    } finally {
      setSavingConfig(false);
    }
  };

  const handleToggleBuyerLoyalty = async (buyerId: string, currentStatus: boolean) => {
    try {
      await api.put(`/loyalty/buyers/${buyerId}/toggle-status`, {
        enabled: !currentStatus,
      });
      setBuyers((prev) =>
        prev.map((b) => (b.id === buyerId ? { ...b, loyaltyEnabled: !currentStatus } : b)),
      );
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to update customer loyalty status');
    }
  };

  const handleOpenAdjust = (buyer: any) => {
    setAdjustModal({
      open: true,
      buyer,
      type: 'CREDIT',
      amount: '',
      reason: '',
      loading: false,
    });
  };

  const handleSubmitAdjustment = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!adjustModal.buyer || !adjustModal.amount) return;

    setAdjustModal((prev) => ({ ...prev, loading: true }));
    try {
      const res: any = await api.post(`/loyalty/buyers/${adjustModal.buyer.id}/adjust-points`, {
        amount: Number(adjustModal.amount),
        type: adjustModal.type,
        reason: adjustModal.reason.trim() || `Manual adjustment by Super Admin`,
      });

      const updatedBalance = res?.currentBalance ?? res?.data?.currentBalance ?? adjustModal.buyer.loyaltyPoints;
      setBuyers((prev) =>
        prev.map((b) =>
          b.id === adjustModal.buyer.id ? { ...b, loyaltyPoints: updatedBalance, loyaltyRupeeValue: updatedBalance } : b,
        ),
      );

      setAdjustModal({ open: false, buyer: null, type: 'CREDIT', amount: '', reason: '', loading: false });
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to adjust loyalty points');
      setAdjustModal((prev) => ({ ...prev, loading: false }));
    }
  };

  const handleOpenHistory = async (buyer: any) => {
    setHistoryModal({ open: true, buyer, history: [], loading: true });
    try {
      const res: any = await api.get(`/loyalty/buyers/${buyer.id}/history`);
      setHistoryModal({
        open: true,
        buyer,
        history: res?.history || res?.data?.history || [],
        loading: false,
      });
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to fetch transaction history');
      setHistoryModal((prev) => ({ ...prev, loading: false }));
    }
  };

  const handleOpenGiftModal = (gift: any = null) => {
    setGiftUploadError(null);
    setGiftModal({
      open: true,
      gift,
      title: gift?.title || '',
      description: gift?.description || '',
      pointsRequired: gift?.pointsRequired ? String(gift.pointsRequired) : '500',
      stockQuantity: gift?.stockQuantity ? String(gift.stockQuantity) : '50',
      imageUrl: gift?.imageUrl || '/uploads/products/sample-ro.jpg',
      isActive: gift ? gift.isActive : true,
      loading: false,
    });
  };

  const handleGiftImageUpload = async (file: File) => {
    if (!file) return;
    setUploadingGiftImage(true);
    setGiftUploadError(null);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const res: any = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const uploadedUrl = res.url || res.relativePath || res.data?.url || res.data?.relativePath;
      if (uploadedUrl) {
        setGiftModal((prev) => ({ ...prev, imageUrl: uploadedUrl }));
      }
    } catch (err: any) {
      setGiftUploadError(`Upload failed: ${err.message || 'Error uploading image'}`);
    } finally {
      setUploadingGiftImage(false);
    }
  };

  const handleSaveGift = async (e: React.FormEvent) => {
    e.preventDefault();
    setGiftModal((prev) => ({ ...prev, loading: true }));
    try {
      const payload = {
        title: giftModal.title.trim(),
        description: giftModal.description.trim(),
        pointsRequired: Number(giftModal.pointsRequired),
        stockQuantity: Number(giftModal.stockQuantity),
        imageUrl: giftModal.imageUrl.trim() || '/uploads/products/sample-ro.jpg',
        isActive: giftModal.isActive,
      };

      if (giftModal.gift) {
        const res: any = await api.put(`/loyalty/gifts/${giftModal.gift.id}`, payload);
        const item = res?.data || res;
        setGifts((prev) => prev.map((g) => (g.id === giftModal.gift.id ? item : g)));
      } else {
        const res: any = await api.post('/loyalty/gifts', payload);
        const item = res?.data || res;
        if (item) setGifts((prev) => [item, ...prev]);
      }

      setGiftModal((prev) => ({ ...prev, open: false, loading: false }));
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to save gift reward');
      setGiftModal((prev) => ({ ...prev, loading: false }));
    }
  };

  const handleDeleteGift = async (giftId: string) => {
    if (!confirm('Are you sure you want to delete this gift reward?')) return;
    try {
      await api.delete(`/loyalty/gifts/${giftId}`);
      setGifts((prev) => prev.filter((g) => g.id !== giftId));
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to delete gift reward');
    }
  };

  const handleUpdateRedemptionStatus = async (redemptionId: string, newStatus: string) => {
    const remarks = prompt(
      newStatus === 'REJECTED'
        ? 'Enter reason for rejection (Points will be automatically refunded to customer):'
        : 'Enter dispatch tracking docket / notes (optional):',
    );
    if (remarks === null) return; // user cancelled prompt

    try {
      const res = await api.put(`/loyalty/redemptions/${redemptionId}/status`, {
        status: newStatus,
        adminRemarks: remarks || undefined,
      });

      setRedemptions((prev) =>
        prev.map((r) => (r.id === redemptionId ? { ...r, status: newStatus, adminRemarks: remarks } : r)),
      );

      // If rejected, reload buyers to reflect refunded points
      if (newStatus === 'REJECTED') {
        const buyersRes = await api.get('/loyalty/buyers');
        if (buyersRes.data?.data) setBuyers(buyersRes.data.data);
      }
    } catch (err: any) {
      alert(err.response?.data?.message || 'Failed to update redemption status');
    }
  };

  const filteredBuyers = buyers.filter((b) => {
    const q = searchBuyer.toLowerCase();
    return (
      b.buyerName?.toLowerCase().includes(q) ||
      b.businessName?.toLowerCase().includes(q) ||
      b.phone?.includes(q)
    );
  });

  return (
    <div className="p-6 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-3">
            <div className="p-2.5 bg-sky-500/10 text-sky-600 rounded-xl">
              <Gift className="w-7 h-7" />
            </div>
            <div>
              <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
                Loyalty Points &amp; Gift Rewards Management
              </h1>
              <p className="text-sm text-slate-500">
                Configure purchase point accrual (% rate), manage customer points, ledger history, and gift redemptions.
              </p>
            </div>
          </div>
        </div>

        <button
          onClick={loadAllData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-slate-700 bg-white border border-slate-200 rounded-xl hover:bg-slate-50 transition shadow-sm"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
          Refresh Data
        </button>
      </div>

      {/* Global Program Settings Card */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm p-6">
        <div className="flex items-center justify-between pb-4 border-b border-slate-100 mb-5">
          <div className="flex items-center gap-2">
            <Sliders className="w-5 h-5 text-sky-600" />
            <h2 className="text-base font-bold text-slate-900">Program Rules &amp; Percentage Accrual</h2>
          </div>
          <div className="flex items-center gap-2">
            <span
              className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold ${
                config.enabled ? 'bg-emerald-50 text-emerald-700 border border-emerald-200' : 'bg-red-50 text-red-700 border border-red-200'
              }`}
            >
              <span className={`w-2 h-2 rounded-full ${config.enabled ? 'bg-emerald-500' : 'bg-red-500'}`} />
              {config.enabled ? 'PROGRAM ACTIVE (ALL BUYERS)' : 'PROGRAM SUSPENDED'}
            </span>
          </div>
        </div>

        <form onSubmit={handleSaveConfig} className="grid grid-cols-1 md:grid-cols-4 gap-6 items-end">
          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
              Global Program Status
            </label>
            <button
              type="button"
              onClick={() => setConfig((prev) => ({ ...prev, enabled: !prev.enabled }))}
              className={`w-full flex items-center justify-between px-4 py-2.5 rounded-xl border text-sm font-bold transition ${
                config.enabled
                  ? 'bg-emerald-50 border-emerald-300 text-emerald-800'
                  : 'bg-red-50 border-red-300 text-red-800'
              }`}
            >
              <span>{config.enabled ? 'Turn ON (Active)' : 'Turn OFF (Suspended)'}</span>
              {config.enabled ? <ToggleRight className="w-6 h-6 text-emerald-600" /> : <ToggleLeft className="w-6 h-6 text-red-600" />}
            </button>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
              Purchase Point Rate (% of Total)
            </label>
            <div className="relative">
              <input
                type="number"
                step="0.1"
                min="0"
                max="50"
                value={config.percentage}
                onChange={(e) => setConfig((prev) => ({ ...prev, percentage: parseFloat(e.target.value) || 0 }))}
                className="w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-slate-900 font-bold focus:bg-white focus:ring-2 focus:ring-sky-500 focus:border-sky-500"
                placeholder="0.5"
                required
              />
              <span className="absolute right-4 top-2.5 font-bold text-slate-400">%</span>
            </div>
            <p className="text-[11px] text-slate-400 mt-1">Normally 0.5% (₹10,000 order = 50 pts)</p>
          </div>

          <div>
            <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-2">
              Point Value Conversion
            </label>
            <div className="px-4 py-2.5 bg-slate-100 rounded-xl border border-slate-200 text-slate-800 font-bold text-sm">
              1 Point = ₹1.00 (Fixed Statutory)
            </div>
            <p className="text-[11px] text-slate-400 mt-1">1 pt = 1 rupee purchasing value</p>
          </div>

          <div>
            <button
              type="submit"
              disabled={savingConfig}
              className="w-full py-2.5 px-4 bg-sky-600 hover:bg-sky-700 text-white font-bold text-sm rounded-xl transition shadow-sm hover:shadow flex items-center justify-center gap-2"
            >
              {savingConfig ? (
                <>
                  <RefreshCw className="w-4 h-4 animate-spin" />
                  Saving...
                </>
              ) : (
                'Save Settings'
              )}
            </button>
          </div>
        </form>

        {configMsg && (
          <div className="mt-4 p-3 bg-emerald-50 text-emerald-800 border border-emerald-200 rounded-xl text-xs font-bold flex items-center gap-2">
            <CheckCircle className="w-4 h-4 text-emerald-600" />
            {configMsg}
          </div>
        )}
      </div>

      {/* Tabs */}
      <div className="flex border-b border-slate-200 gap-8">
        <button
          onClick={() => setActiveTab('buyers')}
          className={`pb-4 text-sm font-bold flex items-center gap-2 border-b-2 transition ${
            activeTab === 'buyers'
              ? 'border-sky-600 text-sky-600'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Users className="w-4 h-4" />
          Buyer Loyalty Accounts ({buyers.length})
        </button>
        <button
          onClick={() => setActiveTab('gifts')}
          className={`pb-4 text-sm font-bold flex items-center gap-2 border-b-2 transition ${
            activeTab === 'gifts'
              ? 'border-sky-600 text-sky-600'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <Gift className="w-4 h-4" />
          Gift Rewards Catalog ({gifts.length})
        </button>
        <button
          onClick={() => setActiveTab('redemptions')}
          className={`pb-4 text-sm font-bold flex items-center gap-2 border-b-2 transition ${
            activeTab === 'redemptions'
              ? 'border-sky-600 text-sky-600'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          <History className="w-4 h-4" />
          Customer Redemptions ({redemptions.length})
        </button>
      </div>

      {/* TAB 1: BUYER ACCOUNTS */}
      {activeTab === 'buyers' && (
        <div className="space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
            <div className="relative max-w-sm w-full">
              <Search className="w-4 h-4 absolute left-3 top-3 text-slate-400" />
              <input
                type="text"
                placeholder="Search buyer by name, shop, or phone..."
                value={searchBuyer}
                onChange={(e) => setSearchBuyer(e.target.value)}
                className="w-full pl-9 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-sky-500"
              />
            </div>
            <div className="text-xs text-slate-500 font-medium">
              Showing {filteredBuyers.length} of {buyers.length} registered buyers
            </div>
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm text-slate-600">
                <thead className="bg-slate-50/80 text-xs uppercase tracking-wider text-slate-500 border-b border-slate-200">
                  <tr>
                    <th className="py-3.5 px-4 font-bold">Buyer Details</th>
                    <th className="py-3.5 px-4 font-bold">Category</th>
                    <th className="py-3.5 px-4 font-bold">Purchases &amp; Orders</th>
                    <th className="py-3.5 px-4 font-bold">Points Balance</th>
                    <th className="py-3.5 px-4 font-bold">Program Status</th>
                    <th className="py-3.5 px-4 font-bold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {filteredBuyers.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="text-center py-12 text-slate-400">
                        No buyer loyalty accounts match your search.
                      </td>
                    </tr>
                  ) : (
                    filteredBuyers.map((b) => (
                      <tr key={b.id} className="hover:bg-slate-50/60 transition">
                        <td className="py-3.5 px-4">
                          <div className="font-bold text-slate-900">{b.buyerName}</div>
                          <div className="text-xs text-slate-500">{b.businessName}</div>
                          <div className="text-[11px] text-slate-400 font-mono">{b.phone}</div>
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="inline-block px-2 py-0.5 rounded text-[11px] font-bold bg-slate-100 text-slate-700">
                            {b.buyerType}
                          </span>
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="font-semibold text-slate-800">
                            ₹{Number(b.totalPurchaseValue).toLocaleString('en-IN')}
                          </div>
                          <div className="text-xs text-slate-400">{b.totalOrders} total orders</div>
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="inline-flex items-center gap-1.5 px-3 py-1 bg-amber-50 text-amber-800 border border-amber-200 rounded-full font-extrabold text-sm">
                            <Coins className="w-4 h-4 text-amber-600" />
                            {b.loyaltyPoints.toLocaleString()} pts
                          </div>
                          <div className="text-[11px] text-slate-400 mt-0.5">Worth ₹{b.loyaltyRupeeValue.toLocaleString()}</div>
                        </td>
                        <td className="py-3.5 px-4">
                          <button
                            onClick={() => handleToggleBuyerLoyalty(b.id, b.loyaltyEnabled)}
                            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-bold transition ${
                              b.loyaltyEnabled
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100'
                                : 'bg-rose-50 text-rose-700 border border-rose-200 hover:bg-rose-100'
                            }`}
                            title="Click to toggle customer loyalty status"
                          >
                            <span className={`w-1.5 h-1.5 rounded-full ${b.loyaltyEnabled ? 'bg-emerald-500' : 'bg-rose-500'}`} />
                            {b.loyaltyEnabled ? 'Active' : 'Disabled (Off)'}
                          </button>
                        </td>
                        <td className="py-3.5 px-4 text-right space-x-2">
                          <button
                            onClick={() => handleOpenAdjust(b)}
                            className="inline-flex items-center gap-1 px-3 py-1.5 bg-sky-50 text-sky-700 hover:bg-sky-100 border border-sky-200 rounded-lg text-xs font-bold transition"
                          >
                            <Coins className="w-3.5 h-3.5" />
                            Adjust Pts
                          </button>
                          <button
                            onClick={() => handleOpenHistory(b)}
                            className="inline-flex items-center gap-1 px-3 py-1.5 bg-slate-100 text-slate-700 hover:bg-slate-200 rounded-lg text-xs font-bold transition"
                          >
                            <History className="w-3.5 h-3.5" />
                            History
                          </button>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* TAB 2: GIFTS CATALOG */}
      {activeTab === 'gifts' && (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <p className="text-sm text-slate-500">
              Gifts offered to buyers in exchange for accumulated loyalty points. 1 Point = ₹1.
            </p>
            <button
              onClick={() => handleOpenGiftModal()}
              className="inline-flex items-center gap-2 px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white rounded-xl text-sm font-bold shadow-sm transition"
            >
              <Plus className="w-4 h-4" />
              Add New Gift Item
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {gifts.map((g) => {
              const imgUrl = g.imageUrl
                ? g.imageUrl.startsWith('http')
                  ? g.imageUrl
                  : `http://192.168.29.44:4000${g.imageUrl.startsWith('/') ? '' : '/'}${g.imageUrl}`
                : '';

              return (
                <div
                  key={g.id}
                  className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col justify-between hover:shadow-md transition"
                >
                  <div>
                    {/* Gift Image Banner */}
                    <div className="w-full h-44 bg-slate-100 relative overflow-hidden flex items-center justify-center border-b border-slate-100">
                      {imgUrl ? (
                        <img
                          src={imgUrl}
                          alt={g.title}
                          className="w-full h-full object-cover"
                          onError={(e: any) => {
                            e.target.style.display = 'none';
                          }}
                        />
                      ) : null}
                      <div className="absolute top-3 left-3">
                        <span className="inline-flex items-center gap-1 px-2.5 py-1 bg-white/95 backdrop-blur-xs text-amber-800 border border-amber-200 rounded-full font-extrabold text-xs shadow-xs">
                          <Coins className="w-3.5 h-3.5 text-amber-600" />
                          {g.pointsRequired} Points
                        </span>
                      </div>
                      <div className="absolute top-3 right-3">
                        <span
                          className={`px-2 py-0.5 rounded text-[10px] font-bold shadow-xs ${
                            g.isActive ? 'bg-emerald-500 text-white' : 'bg-slate-700 text-white'
                          }`}
                        >
                          {g.isActive ? 'Active' : 'Hidden'}
                        </span>
                      </div>
                      {!imgUrl && (
                        <div className="flex flex-col items-center justify-center text-slate-400">
                          <Gift className="w-10 h-10 text-slate-300 mb-1" />
                          <span className="text-xs text-slate-400">Reward Item</span>
                        </div>
                      )}
                    </div>

                    <div className="p-5 pb-0">
                      <h3 className="font-extrabold text-slate-900 text-base mb-1.5 leading-snug">{g.title}</h3>
                      <p className="text-xs text-slate-500 line-clamp-3 mb-4">{g.description || 'Exclusive customer reward gift.'}</p>
                    </div>
                  </div>

                  <div className="p-5 pt-3 border-t border-slate-100 flex items-center justify-between">
                    <div className="text-xs text-slate-500">
                      Stock: <span className="font-bold text-slate-800">{g.stockQuantity} units</span>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => handleOpenGiftModal(g)}
                        className="p-1.5 text-slate-600 hover:text-sky-600 hover:bg-sky-50 rounded-lg transition"
                        title="Edit Gift"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteGift(g.id)}
                        className="p-1.5 text-slate-600 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        title="Delete Gift"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* TAB 3: CUSTOMER REDEMPTIONS */}
      {activeTab === 'redemptions' && (
        <div className="space-y-4">
          <div className="text-sm text-slate-500">
            Review customer gift redemption claims. Updating status to 'Delivered' or 'Dispatched' notifies the customer. Rejecting automatically refunds the points.
          </div>

          <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm text-slate-600">
                <thead className="bg-slate-50/80 text-xs uppercase tracking-wider text-slate-500 border-b border-slate-200">
                  <tr>
                    <th className="py-3.5 px-4 font-bold">Customer Details</th>
                    <th className="py-3.5 px-4 font-bold">Gift Item Claimed</th>
                    <th className="py-3.5 px-4 font-bold">Points Spent</th>
                    <th className="py-3.5 px-4 font-bold">Claimed Date</th>
                    <th className="py-3.5 px-4 font-bold">Status</th>
                    <th className="py-3.5 px-4 font-bold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {redemptions.length === 0 ? (
                    <tr>
                      <td colSpan={6} className="text-center py-12 text-slate-400">
                        No customer gift redemptions recorded yet.
                      </td>
                    </tr>
                  ) : (
                    redemptions.map((r) => (
                      <tr key={r.id} className="hover:bg-slate-50/60 transition">
                        <td className="py-3.5 px-4">
                          <div className="font-bold text-slate-900">{r.buyer?.user?.fullName || r.buyer?.businessName}</div>
                          <div className="text-xs text-slate-400">{r.buyer?.user?.phone}</div>
                          {r.deliveryNotes && (
                            <div className="text-[11px] text-sky-700 bg-sky-50 p-1 rounded mt-1 max-w-xs truncate">
                              Note: {r.deliveryNotes}
                            </div>
                          )}
                        </td>
                        <td className="py-3.5 px-4">
                          <div className="flex items-center gap-2.5">
                            {r.gift?.imageUrl ? (
                              <img
                                src={
                                  r.gift.imageUrl.startsWith('http')
                                    ? r.gift.imageUrl
                                    : `http://192.168.29.44:4000${r.gift.imageUrl.startsWith('/') ? '' : '/'}${r.gift.imageUrl}`
                                }
                                alt=""
                                className="w-9 h-9 object-cover rounded-lg border border-slate-200 shrink-0"
                                onError={(e: any) => {
                                  e.target.style.display = 'none';
                                }}
                              />
                            ) : (
                              <div className="w-9 h-9 rounded-lg bg-slate-100 flex items-center justify-center text-slate-400 shrink-0">
                                <Gift className="w-4 h-4" />
                              </div>
                            )}
                            <div>
                              <div className="font-bold text-slate-800">{r.gift?.title || 'Reward Gift'}</div>
                              <div className="text-[11px] text-slate-400">Stock: {r.gift?.stockQuantity ?? '—'} units</div>
                            </div>
                          </div>
                        </td>
                        <td className="py-3.5 px-4">
                          <span className="font-extrabold text-amber-700 bg-amber-50 px-2 py-0.5 rounded text-xs">
                            -{r.pointsSpent} pts
                          </span>
                        </td>
                        <td className="py-3.5 px-4 text-xs text-slate-500">
                          {new Date(r.redeemedAt).toLocaleString('en-IN', {
                            dateStyle: 'medium',
                            timeStyle: 'short',
                          })}
                        </td>
                        <td className="py-3.5 px-4">
                          <span
                            className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold ${
                              r.status === 'DELIVERED'
                                ? 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                                : r.status === 'DISPATCHED'
                                ? 'bg-sky-50 text-sky-700 border border-sky-200'
                                : r.status === 'APPROVED'
                                ? 'bg-indigo-50 text-indigo-700 border border-indigo-200'
                                : r.status === 'REJECTED'
                                ? 'bg-rose-50 text-rose-700 border border-rose-200'
                                : 'bg-amber-50 text-amber-800 border border-amber-200'
                            }`}
                          >
                            {r.status}
                          </span>
                          {r.adminRemarks && (
                            <div className="text-[11px] text-slate-400 mt-1">{r.adminRemarks}</div>
                          )}
                        </td>
                        <td className="py-3.5 px-4 text-right space-x-1.5">
                          {r.status === 'REQUESTED' && (
                            <>
                              <button
                                onClick={() => handleUpdateRedemptionStatus(r.id, 'APPROVED')}
                                className="px-2.5 py-1 bg-indigo-50 text-indigo-700 hover:bg-indigo-100 rounded text-xs font-bold"
                              >
                                Approve
                              </button>
                              <button
                                onClick={() => handleUpdateRedemptionStatus(r.id, 'REJECTED')}
                                className="px-2.5 py-1 bg-rose-50 text-rose-700 hover:bg-rose-100 rounded text-xs font-bold"
                              >
                                Reject &amp; Refund
                              </button>
                            </>
                          )}
                          {r.status === 'APPROVED' && (
                            <button
                              onClick={() => handleUpdateRedemptionStatus(r.id, 'DISPATCHED')}
                              className="px-2.5 py-1 bg-sky-50 text-sky-700 hover:bg-sky-100 rounded text-xs font-bold"
                            >
                              Dispatch
                            </button>
                          )}
                          {r.status === 'DISPATCHED' && (
                            <button
                              onClick={() => handleUpdateRedemptionStatus(r.id, 'DELIVERED')}
                              className="px-2.5 py-1 bg-emerald-50 text-emerald-700 hover:bg-emerald-100 rounded text-xs font-bold"
                            >
                              Mark Delivered
                            </button>
                          )}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ADJUST POINTS MODAL */}
      {adjustModal.open && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100">
            <h3 className="text-lg font-bold text-slate-900 mb-1">
              Adjust Loyalty Points: {adjustModal.buyer?.buyerName}
            </h3>
            <p className="text-xs text-slate-500 mb-4">
              Current Points Balance:{' '}
              <span className="font-bold text-amber-700">
                {adjustModal.buyer?.loyaltyPoints} points (₹{adjustModal.buyer?.loyaltyRupeeValue})
              </span>
            </p>

            <form onSubmit={handleSubmitAdjustment} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-2">Adjustment Type</label>
                <div className="grid grid-cols-2 gap-3">
                  <button
                    type="button"
                    onClick={() => setAdjustModal((prev) => ({ ...prev, type: 'CREDIT' }))}
                    className={`py-2 px-3 rounded-xl border text-xs font-bold flex items-center justify-center gap-1.5 transition ${
                      adjustModal.type === 'CREDIT'
                        ? 'bg-emerald-50 border-emerald-500 text-emerald-800'
                        : 'bg-slate-50 border-slate-200 text-slate-600'
                    }`}
                  >
                    <ArrowUpRight className="w-4 h-4 text-emerald-600" />
                    Add Points (Credit)
                  </button>
                  <button
                    type="button"
                    onClick={() => setAdjustModal((prev) => ({ ...prev, type: 'DEBIT' }))}
                    className={`py-2 px-3 rounded-xl border text-xs font-bold flex items-center justify-center gap-1.5 transition ${
                      adjustModal.type === 'DEBIT'
                        ? 'bg-rose-50 border-rose-500 text-rose-800'
                        : 'bg-slate-50 border-slate-200 text-slate-600'
                    }`}
                  >
                    <ArrowDownRight className="w-4 h-4 text-rose-600" />
                    Reduce Points (Debit)
                  </button>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Number of Points</label>
                <input
                  type="number"
                  min="1"
                  step="1"
                  value={adjustModal.amount}
                  onChange={(e) => setAdjustModal((prev) => ({ ...prev, amount: e.target.value }))}
                  placeholder="e.g. 100"
                  className="w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl font-bold text-slate-900 focus:bg-white focus:ring-2 focus:ring-sky-500"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Reason / Remarks</label>
                <input
                  type="text"
                  value={adjustModal.reason}
                  onChange={(e) => setAdjustModal((prev) => ({ ...prev, reason: e.target.value }))}
                  placeholder="e.g. Festival bonus / special consideration"
                  className="w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl text-sm focus:bg-white focus:ring-2 focus:ring-sky-500"
                  required
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setAdjustModal((prev) => ({ ...prev, open: false }))}
                  className="px-4 py-2 text-sm font-semibold text-slate-600 hover:text-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={adjustModal.loading}
                  className="px-5 py-2 bg-sky-600 hover:bg-sky-700 text-white font-bold text-sm rounded-xl shadow-sm transition"
                >
                  {adjustModal.loading ? 'Saving...' : 'Confirm Adjustment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* HISTORY MODAL */}
      {historyModal.open && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 flex flex-col max-h-[85vh]">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 mb-4">
              <div>
                <h3 className="text-lg font-bold text-slate-900">
                  Points Ledger History: {historyModal.buyer?.buyerName}
                </h3>
                <p className="text-xs text-slate-500">
                  Current Balance:{' '}
                  <span className="font-extrabold text-amber-700">
                    {historyModal.buyer?.loyaltyPoints} points (₹{historyModal.buyer?.loyaltyRupeeValue})
                  </span>
                </p>
              </div>
              <button
                onClick={() => setHistoryModal((prev) => ({ ...prev, open: false }))}
                className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg"
              >
                ✕
              </button>
            </div>

            <div className="flex-1 overflow-y-auto space-y-3 pr-1">
              {historyModal.loading ? (
                <div className="text-center py-10 text-slate-400 text-sm">Loading ledger transactions...</div>
              ) : historyModal.history.length === 0 ? (
                <div className="text-center py-10 text-slate-400 text-sm">No transaction records found for this buyer.</div>
              ) : (
                historyModal.history.map((h: any) => (
                  <div
                    key={h.id}
                    className="p-3.5 rounded-xl border border-slate-100 bg-slate-50/70 flex items-center justify-between"
                  >
                    <div>
                      <div className="flex items-center gap-2 mb-1">
                        <span
                          className={`px-2 py-0.5 rounded text-[10px] font-extrabold ${
                            h.points > 0
                              ? 'bg-emerald-100 text-emerald-800'
                              : 'bg-rose-100 text-rose-800'
                          }`}
                        >
                          {h.transactionType}
                        </span>
                        <span className="text-xs text-slate-400">
                          {new Date(h.createdAt).toLocaleString('en-IN', {
                            dateStyle: 'medium',
                            timeStyle: 'short',
                          })}
                        </span>
                      </div>
                      <div className="text-xs font-bold text-slate-800">{h.description}</div>
                      <div className="text-[11px] text-slate-400">By: {h.performedBy || 'System'}</div>
                    </div>

                    <div className="text-right">
                      <div
                        className={`font-black text-sm ${
                          h.points > 0 ? 'text-emerald-700' : 'text-rose-700'
                        }`}
                      >
                        {h.points > 0 ? `+${h.points}` : h.points} pts
                      </div>
                      <div className="text-[11px] text-slate-500 font-medium">Bal: {h.balanceAfter} pts</div>
                    </div>
                  </div>
                ))
              )}
            </div>

            <div className="pt-4 border-t border-slate-100 mt-4 text-right">
              <button
                onClick={() => setHistoryModal((prev) => ({ ...prev, open: false }))}
                className="px-5 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 font-bold text-sm rounded-xl transition"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ADD / EDIT GIFT MODAL */}
      {giftModal.open && (
        <div className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100">
            <h3 className="text-lg font-bold text-slate-900 mb-1">
              {giftModal.gift ? 'Edit Gift Reward Item' : 'Create New Gift Reward'}
            </h3>
            <p className="text-xs text-slate-500 mb-4">
              Specify points required for redemption and available stock.
            </p>

            <form onSubmit={handleSaveGift} className="space-y-4">
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Gift Title</label>
                <input
                  type="text"
                  value={giftModal.title}
                  onChange={(e) => setGiftModal((prev) => ({ ...prev, title: e.target.value }))}
                  placeholder="e.g. Grand Aqua Stainless Steel Water Bottle"
                  className="w-full px-4 py-2.5 bg-slate-50 border border-slate-300 rounded-xl font-bold text-slate-900 focus:bg-white focus:ring-2 focus:ring-sky-500 text-sm"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Description / Specifications</label>
                <textarea
                  rows={3}
                  value={giftModal.description}
                  onChange={(e) => setGiftModal((prev) => ({ ...prev, description: e.target.value }))}
                  placeholder="Enter gift description, capacity, or specifications..."
                  className="w-full px-4 py-2 bg-slate-50 border border-slate-300 rounded-xl text-sm focus:bg-white focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Points Required</label>
                  <input
                    type="number"
                    min="1"
                    step="1"
                    value={giftModal.pointsRequired}
                    onChange={(e) => setGiftModal((prev) => ({ ...prev, pointsRequired: e.target.value }))}
                    placeholder="500"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-300 rounded-xl font-bold text-slate-900 focus:bg-white focus:ring-2 focus:ring-sky-500 text-sm"
                    required
                  />
                  <p className="text-[10px] text-slate-400 mt-0.5">Worth ₹{Number(giftModal.pointsRequired || 0)}</p>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase mb-1">Stock Quantity</label>
                  <input
                    type="number"
                    min="0"
                    step="1"
                    value={giftModal.stockQuantity}
                    onChange={(e) => setGiftModal((prev) => ({ ...prev, stockQuantity: e.target.value }))}
                    placeholder="50"
                    className="w-full px-4 py-2 bg-slate-50 border border-slate-300 rounded-xl font-bold text-slate-900 focus:bg-white focus:ring-2 focus:ring-sky-500 text-sm"
                    required
                  />
                </div>
              </div>

              {/* Gift Reward Image Picker & Upload */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase mb-1.5">
                  Gift Reward Image
                </label>
                <div className="flex gap-4 items-start">
                  {/* Thumbnail Preview */}
                  <div className="w-24 h-24 rounded-xl border border-slate-200 bg-slate-50 overflow-hidden flex items-center justify-center shrink-0 relative group">
                    {giftModal.imageUrl ? (
                      <>
                        <img
                          src={
                            giftModal.imageUrl.startsWith('http')
                              ? giftModal.imageUrl
                              : `http://192.168.29.44:4000${giftModal.imageUrl.startsWith('/') ? '' : '/'}${giftModal.imageUrl}`
                          }
                          alt="Preview"
                          className="w-full h-full object-cover"
                          onError={(e: any) => {
                            e.target.style.display = 'none';
                          }}
                        />
                        <button
                          type="button"
                          onClick={() => setGiftModal((prev) => ({ ...prev, imageUrl: '' }))}
                          className="absolute inset-0 bg-black/60 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition text-xs font-bold"
                        >
                          Remove
                        </button>
                      </>
                    ) : (
                      <div className="flex flex-col items-center text-slate-400">
                        <Gift className="w-8 h-8 text-slate-300" />
                        <span className="text-[10px] mt-1 font-medium">No Image</span>
                      </div>
                    )}
                  </div>

                  {/* Upload Actions & URL Input */}
                  <div className="flex-1 space-y-2">
                    <label className="inline-flex items-center gap-2 px-3.5 py-2 bg-sky-50 border border-sky-200 hover:bg-sky-100 text-sky-700 rounded-xl text-xs font-bold cursor-pointer transition">
                      {uploadingGiftImage ? (
                        <>
                          <Loader2 className="w-4 h-4 animate-spin" />
                          <span>Uploading...</span>
                        </>
                      ) : (
                        <>
                          <Upload className="w-4 h-4" />
                          <span>Upload Image File</span>
                        </>
                      )}
                      <input
                        type="file"
                        accept="image/*"
                        className="hidden"
                        disabled={uploadingGiftImage}
                        onChange={(e) => {
                          const file = e.target.files?.[0];
                          if (file) handleGiftImageUpload(file);
                        }}
                      />
                    </label>

                    {giftUploadError && (
                      <p className="text-xs text-rose-600 font-medium">{giftUploadError}</p>
                    )}

                    <div>
                      <input
                        type="text"
                        value={giftModal.imageUrl}
                        onChange={(e) => setGiftModal((prev) => ({ ...prev, imageUrl: e.target.value }))}
                        placeholder="Or image URL (e.g. /uploads/gifts/water-bottle.png)"
                        className="w-full px-3 py-1.5 bg-slate-50 border border-slate-300 rounded-lg text-xs font-mono focus:bg-white focus:ring-2 focus:ring-sky-500"
                      />
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex items-center gap-2 pt-2">
                <input
                  type="checkbox"
                  id="giftIsActive"
                  checked={giftModal.isActive}
                  onChange={(e) => setGiftModal((prev) => ({ ...prev, isActive: e.target.checked }))}
                  className="w-4 h-4 text-sky-600 rounded border-slate-300 focus:ring-sky-500"
                />
                <label htmlFor="giftIsActive" className="text-xs font-bold text-slate-700 cursor-pointer">
                  Active &amp; Available in Buyer Rewards Catalog
                </label>
              </div>

              <div className="flex items-center justify-end gap-3 pt-4 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setGiftModal((prev) => ({ ...prev, open: false }))}
                  className="px-4 py-2 text-sm font-semibold text-slate-600 hover:text-slate-800"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={giftModal.loading}
                  className="px-5 py-2 bg-sky-600 hover:bg-sky-700 text-white font-bold text-sm rounded-xl shadow-sm transition"
                >
                  {giftModal.loading ? 'Saving...' : giftModal.gift ? 'Update Gift' : 'Create Gift'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
