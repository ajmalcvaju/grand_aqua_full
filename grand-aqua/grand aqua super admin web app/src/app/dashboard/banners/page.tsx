'use client';

import React, { useState, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Image as ImageIcon,
  Plus,
  Trash2,
  Edit2,
  Users,
  Check,
  X,
  ExternalLink,
  Layers,
  Sparkles,
  AlertCircle,
  Eye,
  Calendar,
  Search,
  CheckSquare,
  Square,
  Filter,
  Upload,
  Loader2,
  CheckCircle2,
} from 'lucide-react';

const AUDIENCE_OPTIONS = [
  { value: 'ALL_BUYERS', label: '1. All Buyers', description: 'Visible to every registered buyer' },
  { value: 'ALL_WHOLESALERS', label: '2. All Wholesalers', description: 'Visible only to Wholesaler trade accounts' },
  { value: 'ALL_DISTRIBUTORS', label: '3. All Distributors', description: 'Visible only to Regional Distributors' },
  { value: 'ALL_DEALERS', label: '4. All Dealers', description: 'Visible only to Authorized Dealers' },
  { value: 'ALL_CUSTOMERS', label: '5. All Customers', description: 'Visible only to Domestic / Retail Customers' },
  { value: 'SPECIFIC_BUYERS', label: '6. Select Buyers (Targeted)', description: 'Visible strictly to explicitly chosen buyers' },
  { value: 'EXCLUDE_BUYERS', label: '7. Buyers Except Selected Buyers', description: 'Visible to all buyers EXCEPT the chosen ones' },
];

export default function BannerManagementPage() {
  const queryClient = useQueryClient();
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingBanner, setEditingBanner] = useState<any | null>(null);
  const [selectedAudienceFilter, setSelectedAudienceFilter] = useState('ALL');

  // Form State
  const [title, setTitle] = useState('');
  const [subtitle, setSubtitle] = useState('');
  const [imageUrl, setImageUrl] = useState('');
  const [actionUrl, setActionUrl] = useState('');
  const [targetType, setTargetType] = useState('NONE');
  const [targetId, setTargetId] = useState('');
  const [audienceType, setAudienceType] = useState('ALL_BUYERS');
  const [selectedBuyerIds, setSelectedBuyerIds] = useState<string[]>([]);
  const [displayOrder, setDisplayOrder] = useState(0);
  const [isActive, setIsActive] = useState(true);
  const [buyerSearch, setBuyerSearch] = useState('');

  // Image Upload State
  const [isUploading, setIsUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [showManualUrl, setShowManualUrl] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileUpload = async (file: File) => {
    if (!file) return;
    setIsUploading(true);
    setUploadError(null);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const res: any = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const uploadedUrl = res.url || res.relativePath || res.data?.url || res.data?.relativePath;
      if (uploadedUrl) {
        setImageUrl(uploadedUrl);
      } else {
        throw new Error('Server returned empty image URL');
      }
    } catch (err: any) {
      setUploadError(err.message || 'Image upload failed. Please try again.');
    } finally {
      setIsUploading(false);
    }
  };

  // 1. Fetch Banners
  const { data: banners = [], isLoading: isLoadingBanners } = useQuery<any[]>({
    queryKey: ['admin-banners'],
    queryFn: async () => {
      const res = await api.get('/banners');
      return (res as any) || [];
    },
  });

  // 2. Fetch Buyers for multi-select picker
  const { data: buyers = [] } = useQuery<any[]>({
    queryKey: ['admin-all-buyers'],
    queryFn: async () => {
      const res = await api.get('/buyers?limit=200');
      const data = (res as any)?.buyers || (res as any) || [];
      return data;
    },
  });

  // 3. Create / Update Mutation
  const saveMutation = useMutation({
    mutationFn: async (payload: any) => {
      if (editingBanner) {
        return api.put(`/banners/${editingBanner.id}`, payload);
      } else {
        return api.post('/banners', payload);
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-banners'] });
      closeModal();
    },
  });

  // 4. Delete Mutation
  const deleteMutation = useMutation({
    mutationFn: async (id: string) => {
      return api.delete(`/banners/${id}`);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-banners'] });
    },
  });

  // 5. Toggle Active Status
  const toggleStatusMutation = useMutation({
    mutationFn: async ({ id, isActive }: { id: string; isActive: boolean }) => {
      return api.put(`/banners/${id}`, { isActive });
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-banners'] });
    },
  });

  const openCreateModal = () => {
    setEditingBanner(null);
    setTitle('');
    setSubtitle('');
    setImageUrl('');
    setActionUrl('');
    setTargetType('NONE');
    setTargetId('');
    setAudienceType('ALL_BUYERS');
    setSelectedBuyerIds([]);
    setDisplayOrder(banners.length + 1);
    setIsActive(true);
    setBuyerSearch('');
    setIsUploading(false);
    setUploadError(null);
    setShowManualUrl(false);
    setIsModalOpen(true);
  };

  const openEditModal = (banner: any) => {
    setEditingBanner(banner);
    setTitle(banner.title || '');
    setSubtitle(banner.subtitle || '');
    setImageUrl(banner.imageUrl || '');
    setActionUrl(banner.actionUrl || '');
    setTargetType(banner.targetType || 'NONE');
    setTargetId(banner.targetId || '');
    setAudienceType(banner.audienceType || 'ALL_BUYERS');
    setSelectedBuyerIds(banner.selectedBuyerIds || []);
    setDisplayOrder(banner.displayOrder || 0);
    setIsActive(banner.isActive ?? true);
    setBuyerSearch('');
    setIsUploading(false);
    setUploadError(null);
    setShowManualUrl(false);
    setIsModalOpen(true);
  };

  const closeModal = () => {
    setIsModalOpen(false);
    setEditingBanner(null);
    setIsUploading(false);
    setUploadError(null);
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim() || !imageUrl.trim()) {
      alert('Please enter a title and upload a banner image');
      return;
    }

    if (
      (audienceType === 'SPECIFIC_BUYERS' || audienceType === 'EXCLUDE_BUYERS') &&
      selectedBuyerIds.length === 0
    ) {
      alert('Please select at least one buyer for this audience option');
      return;
    }

    saveMutation.mutate({
      title,
      subtitle,
      imageUrl,
      actionUrl,
      targetType,
      targetId,
      audienceType,
      selectedBuyerIds,
      displayOrder: Number(displayOrder),
      isActive,
    });
  };

  const toggleBuyerSelection = (buyerId: string) => {
    if (selectedBuyerIds.includes(buyerId)) {
      setSelectedBuyerIds(selectedBuyerIds.filter((id) => id !== buyerId));
    } else {
      setSelectedBuyerIds([...selectedBuyerIds, buyerId]);
    }
  };

  const filteredBuyersForPicker = buyers.filter((b: any) => {
    const q = buyerSearch.toLowerCase().trim();
    const name = (b.user?.fullName || b.fullName || '').toLowerCase();
    const bName = (b.businessName || '').toLowerCase();
    const phone = (b.user?.phone || b.phone || '').toLowerCase();
    return q === '' || name.includes(q) || bName.includes(q) || phone.includes(q);
  });

  const filteredBanners = banners.filter((b) => {
    if (selectedAudienceFilter === 'ALL') return true;
    return b.audienceType === selectedAudienceFilter;
  });

  const getAudienceBadge = (type: string, buyerCount: number = 0) => {
    switch (type) {
      case 'ALL_BUYERS':
        return { label: '1. All Buyers', bg: 'bg-blue-50 text-blue-700 border-blue-200' };
      case 'ALL_WHOLESALERS':
        return { label: '2. All Wholesalers', bg: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
      case 'ALL_DISTRIBUTORS':
        return { label: '3. All Distributors', bg: 'bg-purple-50 text-purple-700 border-purple-200' };
      case 'ALL_DEALERS':
        return { label: '4. All Dealers', bg: 'bg-amber-50 text-amber-700 border-amber-200' };
      case 'ALL_CUSTOMERS':
        return { label: '5. All Customers', bg: 'bg-cyan-50 text-cyan-700 border-cyan-200' };
      case 'SPECIFIC_BUYERS':
        return { label: `6. Select Buyers (${buyerCount})`, bg: 'bg-indigo-50 text-indigo-700 border-indigo-200' };
      case 'EXCLUDE_BUYERS':
        return { label: `7. Except Selected (${buyerCount})`, bg: 'bg-rose-50 text-rose-700 border-rose-200' };
      default:
        return { label: type, bg: 'bg-slate-50 text-slate-700 border-slate-200' };
    }
  };

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-7xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5">
            <div className="p-2.5 bg-sky-500/10 text-sky-600 rounded-xl">
              <ImageIcon className="w-6 h-6" />
            </div>
            <div>
              <h1 className="text-2xl font-black text-slate-900 tracking-tight">
                Banner Management
              </h1>
              <p className="text-xs sm:text-sm text-slate-500">
                Targeted promotional banners shown in Grand Aqua Buyer App based on selected audience
              </p>
            </div>
          </div>
        </div>

        <button
          onClick={openCreateModal}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-sky-600 hover:bg-sky-700 text-white rounded-xl text-xs sm:text-sm font-bold shadow-md shadow-sky-600/20 transition"
        >
          <Plus className="w-4 h-4" />
          Create New Banner
        </button>
      </div>

      {/* Audience Filter Pills */}
      <div className="flex items-center gap-2 overflow-x-auto pb-1 text-xs">
        <span className="text-slate-400 font-semibold uppercase text-[10px] tracking-wider shrink-0 flex items-center gap-1">
          <Filter className="w-3.5 h-3.5" /> Audience:
        </span>
        <button
          onClick={() => setSelectedAudienceFilter('ALL')}
          className={`px-3 py-1.5 rounded-lg font-semibold shrink-0 transition ${
            selectedAudienceFilter === 'ALL'
              ? 'bg-slate-900 text-white'
              : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
          }`}
        >
          All Audiences ({banners.length})
        </button>
        {AUDIENCE_OPTIONS.map((opt) => {
          const count = banners.filter((b) => b.audienceType === opt.value).length;
          return (
            <button
              key={opt.value}
              onClick={() => setSelectedAudienceFilter(opt.value)}
              className={`px-3 py-1.5 rounded-lg font-semibold shrink-0 transition ${
                selectedAudienceFilter === opt.value
                  ? 'bg-sky-600 text-white shadow-xs'
                  : 'bg-white border border-slate-200 text-slate-600 hover:bg-slate-50'
              }`}
            >
              {opt.label} ({count})
            </button>
          );
        })}
      </div>

      {/* Banners Grid */}
      {isLoadingBanners ? (
        <div className="p-16 text-center text-slate-400 text-xs">Loading banners...</div>
      ) : filteredBanners.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center space-y-3">
          <ImageIcon className="w-12 h-12 text-slate-300 mx-auto" />
          <p className="text-sm font-bold text-slate-700">No Banners Found</p>
          <p className="text-xs text-slate-400 max-w-sm mx-auto">
            No promotional banners created for this audience yet. Click "Create New Banner" to create targeted promotions for your buyers.
          </p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredBanners.map((banner) => {
            const badge = getAudienceBadge(
              banner.audienceType,
              banner.selectedBuyerIds?.length || 0
            );

            return (
              <div
                key={banner.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden flex flex-col group hover:shadow-md transition"
              >
                {/* Banner Image Preview */}
                <div className="relative aspect-16/9 bg-slate-100 overflow-hidden">
                  <img
                    src={banner.imageUrl}
                    alt={banner.title}
                    className="w-full h-full object-cover group-hover:scale-105 transition duration-300"
                    onError={(e) => {
                      (e.target as HTMLElement).style.display = 'none';
                    }}
                  />
                  {/* Order & Status Badges */}
                  <div className="absolute top-2.5 left-2.5 flex items-center gap-1.5">
                    <span className="px-2 py-0.5 rounded-md bg-slate-900/80 backdrop-blur-xs text-white text-[10px] font-bold font-mono">
                      Order: #{banner.displayOrder}
                    </span>
                  </div>

                  <div className="absolute top-2.5 right-2.5">
                    <button
                      onClick={() =>
                        toggleStatusMutation.mutate({
                          id: banner.id,
                          isActive: !banner.isActive,
                        })
                      }
                      className={`px-2.5 py-0.5 rounded-full text-[10px] font-bold shadow-xs transition ${
                        banner.isActive
                          ? 'bg-emerald-500 text-white'
                          : 'bg-slate-400 text-white'
                      }`}
                    >
                      {banner.isActive ? 'Active' : 'Hidden'}
                    </button>
                  </div>
                </div>

                {/* Banner Content */}
                <div className="p-4 flex-1 flex flex-col justify-between space-y-3">
                  <div className="space-y-1.5">
                    {/* Audience Chip */}
                    <div className="flex items-center gap-2">
                      <span
                        className={`inline-block px-2 py-0.5 rounded-md text-[11px] font-bold border ${badge.bg}`}
                      >
                        {badge.label}
                      </span>
                    </div>

                    <h3 className="font-bold text-sm text-slate-900 leading-snug line-clamp-1">
                      {banner.title}
                    </h3>
                    {banner.subtitle && (
                      <p className="text-xs text-slate-500 line-clamp-2">
                        {banner.subtitle}
                      </p>
                    )}
                  </div>

                  {/* Target/Action Preview */}
                  {banner.actionUrl && (
                    <div className="text-[11px] text-sky-600 font-mono truncate flex items-center gap-1">
                      <ExternalLink className="w-3 h-3 shrink-0" />
                      <span className="truncate">{banner.actionUrl}</span>
                    </div>
                  )}

                  {/* Bottom Action Controls */}
                  <div className="pt-2 border-t border-slate-100 flex items-center justify-between">
                    <span className="text-[10px] text-slate-400">
                      Created: {new Date(banner.createdAt).toLocaleDateString()}
                    </span>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => openEditModal(banner)}
                        className="p-1.5 text-slate-500 hover:text-sky-600 hover:bg-sky-50 rounded-lg transition"
                        title="Edit Banner"
                      >
                        <Edit2 className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => {
                          if (confirm(`Delete banner "${banner.title}"?`)) {
                            deleteMutation.mutate(banner.id);
                          }
                        }}
                        className="p-1.5 text-slate-500 hover:text-rose-600 hover:bg-rose-50 rounded-lg transition"
                        title="Delete Banner"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* CREATE / EDIT MODAL */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs">
          <div className="bg-white rounded-3xl max-w-2xl w-full max-h-[90vh] overflow-hidden flex flex-col shadow-2xl border border-slate-100 animate-in fade-in zoom-in-95 duration-200">
            {/* Modal Header */}
            <div className="p-5 border-b border-slate-100 flex items-center justify-between bg-slate-50/50">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-sky-500/10 text-sky-600 rounded-xl">
                  <ImageIcon className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="font-bold text-base text-slate-900">
                    {editingBanner ? 'Edit Promotional Banner' : 'Create New Promotional Banner'}
                  </h2>
                  <p className="text-xs text-slate-500">
                    Configure headline, creative banner image, and targeted buyer audience
                  </p>
                </div>
              </div>
              <button
                onClick={closeModal}
                className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Modal Form Scroll Area */}
            <form onSubmit={handleSave} className="flex-1 overflow-y-auto p-5 space-y-4">
              {/* Title & Subtitle */}
              <div className="space-y-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Banner Title *
                  </label>
                  <input
                    type="text"
                    required
                    placeholder="e.g. Diwali Mega RO Sale / Wholesale Special"
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    className="w-full text-xs sm:text-sm px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500"
                  />
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Subtitle / Promotional Offer Text
                  </label>
                  <input
                    type="text"
                    placeholder="e.g. Flat 15% Off on all 100 GPD high-TDS membranes"
                    value={subtitle}
                    onChange={(e) => setSubtitle(e.target.value)}
                    className="w-full text-xs sm:text-sm px-3.5 py-2.5 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500"
                  />
                </div>
              </div>

              {/* Banner Image Upload & Live Preview */}
              <div>
                <div className="flex items-center justify-between mb-1.5">
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider">
                    Banner Creative Image *
                  </label>
                  <button
                    type="button"
                    onClick={() => setShowManualUrl(!showManualUrl)}
                    className="text-[11px] text-sky-600 hover:text-sky-700 font-medium transition"
                  >
                    {showManualUrl ? 'Hide URL field' : 'Or paste URL'}
                  </button>
                </div>

                {/* Hidden File Input */}
                <input
                  type="file"
                  ref={fileInputRef}
                  accept="image/png,image/jpeg,image/jpg,image/webp,image/svg+xml"
                  className="hidden"
                  onChange={(e) => {
                    const file = e.target.files?.[0];
                    if (file) handleFileUpload(file);
                  }}
                />

                {/* Upload Area / Live Preview */}
                {imageUrl ? (
                  <div className="relative rounded-2xl overflow-hidden border border-slate-200 bg-slate-900 shadow-xs group">
                    <div className="aspect-16/9 w-full max-h-52 overflow-hidden bg-slate-100 flex items-center justify-center">
                      <img
                        src={imageUrl}
                        alt="Banner Preview"
                        className="w-full h-full object-cover"
                        onError={(e) => {
                          (e.target as HTMLElement).style.display = 'none';
                        }}
                      />
                    </div>
                    {/* Hover Overlay Controls */}
                    <div className="absolute inset-0 bg-slate-900/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2.5 p-4">
                      <button
                        type="button"
                        onClick={() => fileInputRef.current?.click()}
                        disabled={isUploading}
                        className="px-3.5 py-2 bg-white text-slate-800 text-xs font-bold rounded-xl shadow-lg hover:bg-slate-50 transition flex items-center gap-1.5"
                      >
                        <Upload className="w-3.5 h-3.5 text-sky-600" />
                        Change Image
                      </button>
                      <button
                        type="button"
                        onClick={() => setImageUrl('')}
                        disabled={isUploading}
                        className="px-3.5 py-2 bg-rose-600 text-white text-xs font-bold rounded-xl shadow-lg hover:bg-rose-700 transition flex items-center gap-1.5"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                        Remove
                      </button>
                    </div>
                    {/* Status Badge */}
                    <div className="absolute top-2.5 right-2.5 px-2.5 py-1 bg-emerald-500/90 text-white text-[10px] font-bold rounded-full backdrop-blur-xs flex items-center gap-1 shadow-sm">
                      <CheckCircle2 className="w-3 h-3" />
                      Image Ready
                    </div>
                  </div>
                ) : (
                  <div
                    onClick={() => !isUploading && fileInputRef.current?.click()}
                    onDragOver={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                    }}
                    onDrop={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                      const file = e.dataTransfer.files?.[0];
                      if (file) handleFileUpload(file);
                    }}
                    className={`border-2 border-dashed rounded-2xl p-6 sm:p-7 text-center cursor-pointer transition ${
                      isUploading
                        ? 'border-sky-300 bg-sky-50/50 cursor-wait'
                        : 'border-slate-300 hover:border-sky-500 hover:bg-sky-50/30 bg-slate-50/50'
                    }`}
                  >
                    {isUploading ? (
                      <div className="flex flex-col items-center justify-center py-3">
                        <Loader2 className="w-8 h-8 text-sky-600 animate-spin mb-2" />
                        <span className="text-xs font-bold text-sky-900">Uploading Banner Image...</span>
                        <span className="text-[11px] text-slate-500 mt-0.5">Please wait</span>
                      </div>
                    ) : (
                      <div className="flex flex-col items-center justify-center">
                        <div className="p-3 bg-sky-100/80 text-sky-600 rounded-2xl mb-2.5 shadow-xs">
                          <Upload className="w-6 h-6" />
                        </div>
                        <h4 className="text-xs sm:text-sm font-bold text-slate-800 mb-1">
                          Click to upload or drag & drop banner image
                        </h4>
                        <p className="text-[11px] text-slate-500 max-w-sm mb-2">
                          PNG, JPG, WEBP, or SVG file from your computer
                        </p>
                        <span className="inline-flex items-center gap-1 text-[10px] font-semibold text-sky-700 bg-sky-100/60 px-2.5 py-0.5 rounded-full">
                          <Sparkles className="w-3 h-3" /> Recommended 16:9 widescreen or 2:1 ratio
                        </span>
                      </div>
                    )}
                  </div>
                )}

                {/* Upload Error Alert */}
                {uploadError && (
                  <div className="mt-2 p-2.5 bg-rose-50 border border-rose-200 text-rose-700 text-xs rounded-xl flex items-center justify-between">
                    <div className="flex items-center gap-1.5">
                      <AlertCircle className="w-4 h-4 shrink-0" />
                      <span>{uploadError}</span>
                    </div>
                    <button
                      type="button"
                      onClick={() => setUploadError(null)}
                      className="text-rose-500 hover:text-rose-700"
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                )}

                {/* Optional Manual URL Input */}
                {showManualUrl && (
                  <div className="mt-2.5 animate-in fade-in duration-200">
                    <input
                      type="text"
                      placeholder="Paste image URL (https://... or /uploads/...)"
                      value={imageUrl}
                      onChange={(e) => setImageUrl(e.target.value)}
                      className="w-full text-xs px-3.5 py-2 rounded-xl border border-slate-200 focus:outline-hidden focus:ring-2 focus:ring-sky-500/20 focus:border-sky-500"
                    />
                  </div>
                )}
              </div>

              {/* AUDIENCE SELECTOR (The 7 Options requested by User) */}
              <div className="p-4 bg-sky-50/50 rounded-2xl border border-sky-100 space-y-3">
                <div className="flex items-center gap-2">
                  <Users className="w-4 h-4 text-sky-600" />
                  <label className="text-xs font-bold text-sky-950 uppercase tracking-wider">
                    Target Audience (Choose who sees this banner) *
                  </label>
                </div>

                <div className="grid grid-cols-1 gap-2">
                  {AUDIENCE_OPTIONS.map((opt) => {
                    const isSelected = audienceType === opt.value;
                    return (
                      <label
                        key={opt.value}
                        className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition ${
                          isSelected
                            ? 'bg-white border-sky-500 shadow-xs'
                            : 'bg-white/60 border-slate-200 hover:bg-white'
                        }`}
                      >
                        <input
                          type="radio"
                          name="audience"
                          value={opt.value}
                          checked={isSelected}
                          onChange={() => setAudienceType(opt.value)}
                          className="mt-0.5 text-sky-600 focus:ring-sky-500"
                        />
                        <div className="text-xs">
                          <p className={`font-bold ${isSelected ? 'text-sky-900' : 'text-slate-800'}`}>
                            {opt.label}
                          </p>
                          <p className="text-[11px] text-slate-500">{opt.description}</p>
                        </div>
                      </label>
                    );
                  })}
                </div>

                {/* IF OPTION 6 OR 7 IS SELECTED: MULTI-SELECT BUYERS PICKER */}
                {(audienceType === 'SPECIFIC_BUYERS' || audienceType === 'EXCLUDE_BUYERS') && (
                  <div className="mt-3 pt-3 border-t border-sky-200/60 space-y-2">
                    <div className="flex items-center justify-between text-xs font-bold text-slate-800">
                      <span>
                        {audienceType === 'SPECIFIC_BUYERS'
                          ? 'Select buyers to target:'
                          : 'Select buyers to exclude:'}
                      </span>
                      <span className="text-sky-600 font-mono">
                        {selectedBuyerIds.length} chosen
                      </span>
                    </div>

                    {/* Search box within buyers */}
                    <div className="relative">
                      <Search className="w-3.5 h-3.5 absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
                      <input
                        type="text"
                        placeholder="Search buyer by business, name or phone..."
                        value={buyerSearch}
                        onChange={(e) => setBuyerSearch(e.target.value)}
                        className="w-full pl-8 pr-3 py-1.5 text-xs bg-white border border-slate-200 rounded-lg focus:outline-hidden focus:ring-2 focus:ring-sky-500/20"
                      />
                    </div>

                    {/* Scrollable Checkbox List of Buyers */}
                    <div className="max-h-48 overflow-y-auto bg-white border border-slate-200 rounded-xl divide-y divide-slate-100">
                      {filteredBuyersForPicker.length === 0 ? (
                        <div className="p-4 text-center text-xs text-slate-400">
                          No matching buyers found
                        </div>
                      ) : (
                        filteredBuyersForPicker.map((b: any) => {
                          const isChecked = selectedBuyerIds.includes(b.id);
                          const name = b.user?.fullName || b.fullName || 'Buyer';
                          const phone = b.user?.phone || b.phone || '';
                          const bType = b.buyerType || 'CUSTOMER';

                          return (
                            <div
                              key={b.id}
                              onClick={() => toggleBuyerSelection(b.id)}
                              className={`p-2.5 flex items-center justify-between cursor-pointer hover:bg-slate-50 transition text-xs ${
                                isChecked ? 'bg-sky-50/60' : ''
                              }`}
                            >
                              <div className="flex items-center gap-2.5">
                                {isChecked ? (
                                  <CheckSquare className="w-4 h-4 text-sky-600 shrink-0" />
                                ) : (
                                  <Square className="w-4 h-4 text-slate-300 shrink-0" />
                                )}
                                <div>
                                  <p className="font-bold text-slate-900">{b.businessName || name}</p>
                                  <p className="text-[11px] text-slate-500">
                                    {name} • {phone}
                                  </p>
                                </div>
                              </div>
                              <span className="text-[10px] px-1.5 py-0.5 rounded-sm bg-slate-100 text-slate-600 font-mono">
                                {bType}
                              </span>
                            </div>
                          );
                        })
                      )}
                    </div>
                  </div>
                )}
              </div>

              {/* Order & Active Status */}
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Display Order (Rank)
                  </label>
                  <input
                    type="number"
                    min={0}
                    value={displayOrder}
                    onChange={(e) => setDisplayOrder(parseInt(e.target.value) || 0)}
                    className="w-full text-xs sm:text-sm px-3.5 py-2.5 rounded-xl border border-slate-200"
                  />
                </div>

                <div className="flex flex-col justify-center">
                  <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                    Banner Visibility
                  </label>
                  <label className="flex items-center gap-2 cursor-pointer mt-1">
                    <input
                      type="checkbox"
                      checked={isActive}
                      onChange={(e) => setIsActive(e.target.checked)}
                      className="w-4 h-4 text-sky-600 rounded-sm"
                    />
                    <span className="text-xs font-semibold text-slate-800">
                      Active (Visible to target audience)
                    </span>
                  </label>
                </div>
              </div>

              {/* Action Link (Optional) */}
              <div>
                <label className="block text-xs font-bold text-slate-700 uppercase tracking-wider mb-1">
                  Optional Action Link (e.g. /cart, /category, /quotations)
                </label>
                <input
                  type="text"
                  placeholder="e.g. /category/domestic-ro or external promo link"
                  value={actionUrl}
                  onChange={(e) => setActionUrl(e.target.value)}
                  className="w-full text-xs sm:text-sm px-3.5 py-2.5 rounded-xl border border-slate-200"
                />
              </div>

              {/* Submit Buttons */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-3">
                <button
                  type="button"
                  onClick={closeModal}
                  className="px-4 py-2 border border-slate-200 rounded-xl text-xs font-bold text-slate-600 hover:bg-slate-50 transition"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={saveMutation.isPending}
                  className="px-5 py-2 bg-sky-600 hover:bg-sky-700 text-white rounded-xl text-xs font-bold shadow-md shadow-sky-600/20 transition disabled:opacity-50"
                >
                  {saveMutation.isPending
                    ? 'Saving...'
                    : editingBanner
                    ? 'Update Banner'
                    : 'Save & Publish Banner'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
