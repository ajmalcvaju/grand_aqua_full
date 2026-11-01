'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Users,
  Search,
  Filter,
  UserPlus,
  ShieldAlert,
  ArrowRight,
  CheckCircle,
  Clock,
  Award,
  CreditCard,
  Eye,
  AlertTriangle,
  X,
  Upload,
  Loader2,
  Edit,
  Trash2,
  Store,
  Camera,
  Calendar,
  AlertCircle,
  Package,
  CheckCircle2,
  Phone,
  Mail,
  MapPin,
  ChevronDown,
  Sparkles,
  FileText,
} from 'lucide-react';

const BUYER_TYPES = ['ALL', 'CUSTOMER', 'DEALER', 'WHOLESALER', 'DISTRIBUTOR'];
const LOYALTY_TIERS = [
  { value: 'NONE', label: 'Standard (None)', color: 'bg-slate-100 text-slate-700' },
  { value: 'GOLD', label: 'Gold Tier', color: 'bg-amber-100 text-amber-800 border-amber-300' },
  { value: 'DIAMOND', label: 'Diamond Tier', color: 'bg-sky-100 text-sky-800 border-sky-300' },
  { value: 'PLATINUM', label: 'Platinum Tier', color: 'bg-purple-100 text-purple-800 border-purple-300' },
];

interface BuyerFormState {
  id?: string;
  fullName: string;
  username: string;
  phone: string;
  email: string;
  password?: string;
  businessName: string;
  businessType: string;
  gstin: string;
  billingAddress: string;
  shippingAddress: string;
  district: string;
  state: string;
  pinCode: string;
  buyerType: string;
  loyaltyTier: string;
  creditLimit: number;
  creditDays: number;
  ownerPhoto: string;
  shopPhoto: string;
  assignedSalesmanId: string;
}

const initialFormState: BuyerFormState = {
  fullName: '',
  username: '',
  phone: '',
  email: '',
  password: '',
  businessName: '',
  businessType: 'Retail Shop / Hardware',
  gstin: '',
  billingAddress: '',
  shippingAddress: '',
  district: '',
  state: 'Kerala',
  pinCode: '',
  buyerType: 'DEALER',
  loyaltyTier: 'NONE',
  creditLimit: 0,
  creditDays: 30,
  ownerPhoto: '',
  shopPhoto: '',
  assignedSalesmanId: '',
};

export default function BuyersManagementPage() {
  const queryClient = useQueryClient();
  const [selectedType, setSelectedType] = useState('ALL');
  const [search, setSearch] = useState('');
  const [selectedBuyerId, setSelectedBuyerId] = useState<string | null>(null);
  const [profileActiveTab, setProfileActiveTab] = useState<'purchases' | 'payments' | 'info'>('purchases');
  
  // CRUD Modal States
  const [isFormModalOpen, setIsFormModalOpen] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [formState, setFormState] = useState<BuyerFormState>(initialFormState);
  const [uploadingField, setUploadingField] = useState<'owner' | 'shop' | null>(null);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Promote / Category Modal State
  const [promoteModalBuyer, setPromoteModalBuyer] = useState<any>(null);
  const [newType, setNewType] = useState('DEALER');
  const [promoteReason, setPromoteReason] = useState('');

  // Fetch buyers list
  const { data, isLoading } = useQuery({
    queryKey: ['buyers-list', selectedType, search],
    queryFn: () => {
      let url = `/buyers?search=${encodeURIComponent(search)}`;
      if (selectedType !== 'ALL') url += `&buyerType=${selectedType}`;
      return api.get(url);
    },
  });

  const buyers = (data as any)?.buyers || [];

  // Fetch salesmen for dropdown
  const { data: salesmenData } = useQuery({
    queryKey: ['salesmen-dropdown'],
    queryFn: () => api.get('/salesmen'),
  });
  const salesmen = (salesmenData as any)?.salesmen || (Array.isArray(salesmenData) ? salesmenData : []);

  // Fetch single buyer detailed profile when viewing
  const { data: rawBuyerDetail, isLoading: isLoadingProfile } = useQuery({
    queryKey: ['buyer-detail', selectedBuyerId],
    queryFn: () => (selectedBuyerId ? api.get(`/buyers/${selectedBuyerId}`) : null),
    enabled: !!selectedBuyerId,
  });
  const buyerDetail: any = rawBuyerDetail;

  // File Upload Handler
  const handleFileUpload = async (file: File, field: 'owner' | 'shop') => {
    if (!file) return;
    setUploadingField(field);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const res: any = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const uploadedUrl = res.url || res.relativePath;
      if (field === 'owner') setFormState((prev) => ({ ...prev, ownerPhoto: uploadedUrl }));
      else setFormState((prev) => ({ ...prev, shopPhoto: uploadedUrl }));
    } catch (err: any) {
      alert(`Upload failed: ${err.message}`);
    } finally {
      setUploadingField(null);
    }
  };

  // Create Buyer Mutation
  const createMutation = useMutation({
    mutationFn: (newBuyer: any) => api.post('/buyers', newBuyer),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      setIsFormModalOpen(false);
      setFormState(initialFormState);
      alert('Buyer registered successfully with trade credentials and credit facilities.');
    },
    onError: (err: any) => {
      alert(`Failed to create buyer: ${err.message}`);
    },
  });

  // Update Buyer Mutation
  const updateMutation = useMutation({
    mutationFn: (vars: { id: string; data: any }) => api.put(`/buyers/${vars.id}`, vars.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      queryClient.invalidateQueries({ queryKey: ['buyer-detail', formState.id] });
      setIsFormModalOpen(false);
      alert('Buyer details updated successfully.');
    },
    onError: (err: any) => {
      alert(`Failed to update buyer: ${err.message}`);
    },
  });

  // Delete Buyer Mutation
  const deleteMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/buyers/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      setDeleteConfirmId(null);
      if (selectedBuyerId === deleteConfirmId) setSelectedBuyerId(null);
      alert('Buyer deleted successfully.');
    },
    onError: (err: any) => {
      alert(`Failed to delete buyer: ${err.message}`);
    },
  });

  // Quick Loyalty Tier Change Mutation
  const loyaltyTierMutation = useMutation({
    mutationFn: (vars: { id: string; newTier: string; reason?: string }) =>
      api.put(`/buyers/${vars.id}/loyalty-tier`, {
        newTier: vars.newTier,
        reason: vars.reason || `Loyalty tier changed to ${vars.newTier} by Super Admin`,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      queryClient.invalidateQueries({ queryKey: ['buyer-detail', selectedBuyerId] });
      alert('Buyer loyalty tier updated successfully!');
    },
    onError: (err: any) => {
      alert(`Failed to update tier: ${err.message}`);
    },
  });

  // Category Promote Mutation
  const promoteMutation = useMutation({
    mutationFn: (vars: { id: string; newType: string; reason: string }) =>
      api.put(`/buyers/${vars.id}/promote-type`, {
        newType: vars.newType,
        reason: vars.reason,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      setPromoteModalBuyer(null);
      setPromoteReason('');
      alert('Buyer category changed successfully.');
    },
    onError: (err: any) => {
      alert(`Failed to change category: ${err.message}`);
    },
  });

  // Status Mutation
  const statusMutation = useMutation({
    mutationFn: (vars: { id: string; status: string }) =>
      api.put(`/buyers/${vars.id}/status`, { status: vars.status }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
    },
  });

  const handleOpenCreateModal = () => {
    setFormMode('create');
    setFormState(initialFormState);
    setIsFormModalOpen(true);
  };

  const handleOpenEditModal = (buyer: any) => {
    setFormMode('edit');
    setFormState({
      id: buyer.id,
      fullName: buyer.user?.fullName || '',
      username: buyer.user?.username || '',
      phone: buyer.user?.phone || '',
      email: buyer.user?.email || '',
      businessName: buyer.businessName || '',
      businessType: buyer.businessType || 'Retail Shop / Hardware',
      gstin: buyer.gstin || '',
      billingAddress: buyer.billingAddress || '',
      shippingAddress: buyer.shippingAddress || '',
      district: buyer.district || '',
      state: buyer.state || 'Kerala',
      pinCode: buyer.pinCode || '',
      buyerType: buyer.buyerType || 'DEALER',
      loyaltyTier: buyer.loyaltyTier || 'NONE',
      creditLimit: Number(buyer.creditLimit || buyer.creditAccount?.creditLimit || 0),
      creditDays: Number(buyer.creditDays || buyer.creditAccount?.paymentTermsDays || 30),
      ownerPhoto: buyer.ownerPhoto || buyer.user?.profilePhoto || '',
      shopPhoto: buyer.shopPhoto || '',
      assignedSalesmanId: buyer.assignedSalesmanId || '',
    });
    setIsFormModalOpen(true);
  };

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formState.fullName.trim() || !formState.phone.trim()) {
      alert('Full name and mobile number are required.');
      return;
    }
    if (formMode === 'create') {
      createMutation.mutate(formState);
    } else {
      updateMutation.mutate({ id: formState.id!, data: formState });
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Header */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Buyer Management</h1>
          <p className="text-sm text-slate-500">
            Control customer, dealer, wholesaler, distributor accounts, shop & owner media, loyalty tiers, and credit dues.
          </p>
        </div>

        <button
          onClick={handleOpenCreateModal}
          className="flex items-center gap-2 px-4 py-2.5 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md shadow-sky-600/20 transition-all cursor-pointer"
        >
          <UserPlus className="w-4 h-4" />
          <span>Add New Buyer</span>
        </button>
      </div>

      {/* Tabs & Search Controls */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm space-y-4">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4">
          {/* Category Tabs */}
          <div className="flex flex-wrap items-center gap-1.5 p-1 bg-slate-100 rounded-xl w-full md:w-auto">
            {BUYER_TYPES.map((type) => (
              <button
                key={type}
                onClick={() => setSelectedType(type)}
                className={`px-3 py-1.5 text-xs font-bold rounded-lg transition-all ${
                  selectedType === type
                    ? 'bg-white text-sky-700 shadow-sm'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {type === 'ALL' ? 'All Buyers' : type}
              </button>
            ))}
          </div>

          {/* Search Box */}
          <div className="relative w-full md:w-80">
            <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
            <input
              type="text"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by name, business, phone, ID..."
              className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
            />
          </div>
        </div>
      </div>

      {/* Buyers Data Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Buyer & Media</th>
                <th className="px-5 py-3.5">Category</th>
                <th className="px-5 py-3.5">Loyalty Tier</th>
                <th className="px-5 py-3.5">Assigned Salesman</th>
                <th className="px-5 py-3.5">Credit Facility</th>
                <th className="px-5 py-3.5">Outstanding & Due Date</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-slate-400">
                    <Loader2 className="w-6 h-6 animate-spin mx-auto mb-2 text-sky-600" />
                    Loading buyers database...
                  </td>
                </tr>
              ) : buyers.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-slate-400">
                    No buyers found matching criteria.
                  </td>
                </tr>
              ) : (
                buyers.map((buyer: any) => {
                  const due = buyer.dueSummary || {};
                  const outstanding = Number(due.outstandingAmount ?? buyer.outstandingBalance ?? 0);
                  const daysLeft = due.daysLeft;
                  const isOverdue = due.isOverdue;
                  const ownerPhoto = buyer.ownerPhoto || buyer.user?.profilePhoto;

                  return (
                    <tr key={buyer.id} className="hover:bg-slate-50/80 transition-colors">
                      {/* Buyer Name & Photo */}
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-3">
                          {ownerPhoto ? (
                            <img
                              src={ownerPhoto}
                              alt="Owner"
                              className="w-10 h-10 rounded-full object-cover border border-slate-200 shadow-sm flex-shrink-0"
                            />
                          ) : (
                            <div className="w-10 h-10 rounded-full bg-sky-100 text-sky-700 font-bold flex items-center justify-center border border-sky-200 flex-shrink-0 text-sm">
                              {(buyer.businessName || buyer.user?.fullName || 'B').charAt(0).toUpperCase()}
                            </div>
                          )}
                          <div className="min-w-0">
                            <div className="font-bold text-slate-900 truncate">
                              {buyer.businessName || buyer.user?.fullName}
                            </div>
                            <div className="text-[11px] text-slate-500 flex flex-wrap items-center gap-1.5 mt-0.5 font-mono">
                              <span className="text-sky-600 font-semibold">{buyer.buyerId}</span>
                              {buyer.user?.username ? (
                                <>
                                  <span className="text-slate-300">•</span>
                                  <span className="text-indigo-600 font-semibold bg-indigo-50 px-1.5 py-0.5 rounded">@{buyer.user.username}</span>
                                </>
                              ) : (
                                <>
                                  <span className="text-slate-300">•</span>
                                  <span className="text-amber-600 font-medium bg-amber-50 px-1.5 py-0.5 rounded text-[10px]">No Username Set</span>
                                </>
                              )}
                              <span className="text-slate-300">•</span>
                              <span>{buyer.user?.phone || 'N/A'}</span>
                            </div>
                            {buyer.shopPhoto && (
                              <span className="inline-flex items-center gap-1 text-[10px] text-emerald-600 font-semibold mt-0.5">
                                <Store className="w-3 h-3" /> Shop Photo Attached
                              </span>
                            )}
                          </div>
                        </div>
                      </td>

                      {/* Category */}
                      <td className="px-5 py-3.5">
                        <span
                          className={`inline-block px-2.5 py-1 rounded-full text-[11px] font-extrabold uppercase ${
                            buyer.buyerType === 'DISTRIBUTOR'
                              ? 'bg-sky-100 text-sky-800'
                              : buyer.buyerType === 'WHOLESALER'
                              ? 'bg-cyan-100 text-cyan-800'
                              : buyer.buyerType === 'DEALER'
                              ? 'bg-teal-100 text-teal-800'
                              : 'bg-slate-100 text-slate-700'
                          }`}
                        >
                          {buyer.buyerType}
                        </span>
                      </td>

                      {/* Loyalty Tier with 1-Click Switch */}
                      <td className="px-5 py-3.5">
                        <div className="flex items-center gap-1.5">
                          <span
                            className={`inline-flex items-center gap-1 px-2.5 py-1 rounded-md text-[11px] font-bold border ${
                              buyer.loyaltyTier === 'DIAMOND'
                                ? 'bg-sky-50 text-sky-700 border-sky-300'
                                : buyer.loyaltyTier === 'GOLD'
                                ? 'bg-amber-50 text-amber-700 border-amber-300'
                                : buyer.loyaltyTier === 'PLATINUM'
                                ? 'bg-purple-50 text-purple-700 border-purple-300'
                                : 'bg-slate-50 text-slate-500 border-slate-200 font-normal'
                            }`}
                          >
                            <Award className="w-3.5 h-3.5" />
                            {buyer.loyaltyTier}
                          </span>

                          <select
                            value={buyer.loyaltyTier}
                            onChange={(e) => loyaltyTierMutation.mutate({ id: buyer.id, newTier: e.target.value })}
                            className="text-[10px] bg-white border border-slate-200 rounded p-0.5 font-bold text-slate-600 hover:border-sky-500 cursor-pointer"
                            title="Change Loyalty Tier"
                          >
                            <option value="NONE">Standard</option>
                            <option value="GOLD">🥇 Gold</option>
                            <option value="DIAMOND">💎 Diamond</option>
                            <option value="PLATINUM">🏆 Platinum</option>
                          </select>
                        </div>
                      </td>

                      {/* Assigned Salesman */}
                      <td className="px-5 py-3.5 text-slate-700">
                        {buyer.assignedSalesman?.user?.fullName ? (
                          <div>
                            <div className="font-medium text-slate-900">{buyer.assignedSalesman.user.fullName}</div>
                            <div className="text-[10px] text-slate-400">{buyer.assignedSalesman.employeeCode}</div>
                          </div>
                        ) : (
                          <span className="text-slate-400 italic">Unassigned</span>
                        )}
                      </td>

                      {/* Credit Facility */}
                      <td className="px-5 py-3.5">
                        <div>
                          <span className="text-slate-900 font-bold font-mono">
                            ₹{Number(buyer.creditLimit || buyer.creditAccount?.creditLimit || 0).toLocaleString('en-IN')}
                          </span>
                          <div className="text-[10px] text-slate-400">
                            {buyer.creditDays || buyer.creditAccount?.paymentTermsDays || 30} Days Terms
                          </div>
                        </div>
                      </td>

                      {/* Outstanding & Days Left */}
                      <td className="px-5 py-3.5 font-mono">
                        <div>
                          <div className={`font-bold ${outstanding > 0 ? 'text-rose-600' : 'text-slate-500'}`}>
                            ₹{outstanding.toLocaleString('en-IN')}
                          </div>
                          {outstanding > 0 ? (
                            isOverdue ? (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-rose-100 text-rose-700 border border-rose-200 animate-pulse">
                                <AlertTriangle className="w-2.5 h-2.5" />
                                {due.statusText || 'Overdue'}
                              </span>
                            ) : (
                              <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-teal-50 text-teal-700 border border-teal-200">
                                <Clock className="w-2.5 h-2.5" />
                                {daysLeft !== null ? `${daysLeft} days left` : 'Within Terms'}
                              </span>
                            )
                          ) : (
                            <span className="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-50 text-emerald-700">
                              <CheckCircle className="w-2.5 h-2.5" /> No Dues
                            </span>
                          )}
                        </div>
                      </td>

                      {/* Account Status */}
                      <td className="px-5 py-3.5">
                        <span
                          className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                            buyer.accountStatus === 'ACTIVE'
                              ? 'bg-emerald-50 text-emerald-700'
                              : buyer.accountStatus === 'SUSPENDED'
                              ? 'bg-amber-50 text-amber-700'
                              : 'bg-red-50 text-red-700'
                          }`}
                        >
                          {buyer.accountStatus}
                        </span>
                      </td>

                      {/* Actions */}
                      <td className="px-5 py-3.5 text-right space-x-1">
                        <button
                          onClick={() => {
                            setSelectedBuyerId(buyer.id);
                            setProfileActiveTab('purchases');
                          }}
                          className="px-2.5 py-1 text-sky-600 hover:bg-sky-50 font-bold rounded-lg transition-colors inline-flex items-center gap-1"
                          title="View Purchase & Payment History"
                        >
                          <Eye className="w-3.5 h-3.5" />
                          <span>History</span>
                        </button>

                        <button
                          onClick={() => handleOpenEditModal(buyer)}
                          className="p-1.5 text-slate-600 hover:text-sky-600 hover:bg-slate-100 rounded-lg transition-colors inline-block"
                          title="Edit Buyer"
                        >
                          <Edit className="w-3.5 h-3.5" />
                        </button>

                        <button
                          onClick={() => setDeleteConfirmId(buyer.id)}
                          className="p-1.5 text-rose-500 hover:text-rose-700 hover:bg-rose-50 rounded-lg transition-colors inline-block"
                          title="Delete Buyer"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
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

      {/* CREATE / EDIT BUYER MODAL */}
      {isFormModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 max-h-[90vh] overflow-y-auto space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <UserPlus className="w-4 h-4 text-sky-600" />
                  {formMode === 'create' ? 'Add New Trade Buyer' : 'Edit Buyer Details'}
                </h2>
                <p className="text-xs text-slate-400">
                  Configure buyer profile, contact credentials, shop storefront, and credit terms.
                </p>
              </div>
              <button
                onClick={() => setIsFormModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleFormSubmit} className="space-y-4 text-xs">
              {/* 1. SHOP & OWNER IMAGE UPLOADS */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 space-y-3">
                <span className="font-bold text-slate-700 block">Shop Storefront & Owner Photographs</span>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  {/* Owner Photo */}
                  <div className="bg-white p-3 rounded-lg border border-slate-200">
                    <label className="block font-bold text-slate-700 mb-1 flex items-center gap-1.5">
                      <Camera className="w-3.5 h-3.5 text-sky-600" />
                      Owner Photograph
                    </label>
                    {formState.ownerPhoto ? (
                      <div className="flex items-center gap-2 mt-2">
                        <img
                          src={formState.ownerPhoto}
                          alt="Owner"
                          className="w-12 h-12 rounded-full object-cover border border-slate-200"
                        />
                        <div className="overflow-hidden">
                          <p className="text-[10px] text-emerald-600 font-bold flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" /> Image Uploaded
                          </p>
                          <button
                            type="button"
                            onClick={() => setFormState({ ...formState, ownerPhoto: '' })}
                            className="text-[10px] text-rose-600 hover:underline font-bold"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ) : (
                      <label className="mt-1 border border-dashed border-sky-300 hover:border-sky-500 rounded-lg p-2.5 flex flex-col items-center justify-center cursor-pointer bg-sky-50/40 text-center">
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            if (e.target.files?.[0]) handleFileUpload(e.target.files[0], 'owner');
                          }}
                        />
                        {uploadingField === 'owner' ? (
                          <div className="flex items-center gap-1 text-sky-600">
                            <Loader2 className="w-4 h-4 animate-spin" />
                            <span className="text-[10px] font-bold">Uploading...</span>
                          </div>
                        ) : (
                          <>
                            <Upload className="w-4 h-4 text-sky-500 mb-0.5" />
                            <span className="text-[11px] font-bold text-slate-700">Upload Owner Photo</span>
                          </>
                        )}
                      </label>
                    )}
                  </div>

                  {/* Shop Photo */}
                  <div className="bg-white p-3 rounded-lg border border-slate-200">
                    <label className="block font-bold text-slate-700 mb-1 flex items-center gap-1.5">
                      <Store className="w-3.5 h-3.5 text-emerald-600" />
                      Shop / Storefront Photograph
                    </label>
                    {formState.shopPhoto ? (
                      <div className="flex items-center gap-2 mt-2">
                        <img
                          src={formState.shopPhoto}
                          alt="Shop"
                          className="w-14 h-10 rounded-lg object-cover border border-slate-200"
                        />
                        <div className="overflow-hidden">
                          <p className="text-[10px] text-emerald-600 font-bold flex items-center gap-1">
                            <CheckCircle2 className="w-3 h-3" /> Shop Image Uploaded
                          </p>
                          <button
                            type="button"
                            onClick={() => setFormState({ ...formState, shopPhoto: '' })}
                            className="text-[10px] text-rose-600 hover:underline font-bold"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ) : (
                      <label className="mt-1 border border-dashed border-emerald-300 hover:border-emerald-500 rounded-lg p-2.5 flex flex-col items-center justify-center cursor-pointer bg-emerald-50/40 text-center">
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            if (e.target.files?.[0]) handleFileUpload(e.target.files[0], 'shop');
                          }}
                        />
                        {uploadingField === 'shop' ? (
                          <div className="flex items-center gap-1 text-emerald-600">
                            <Loader2 className="w-4 h-4 animate-spin" />
                            <span className="text-[10px] font-bold">Uploading...</span>
                          </div>
                        ) : (
                          <>
                            <Upload className="w-4 h-4 text-emerald-500 mb-0.5" />
                            <span className="text-[11px] font-bold text-slate-700">Upload Shop Photo</span>
                          </>
                        )}
                      </label>
                    )}
                  </div>
                </div>
              </div>

              {/* 2. BASIC PROFILE & CONTACT */}
              <div className="flex flex-col gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Full Name / Contact Person *</label>
                  <input
                    type="text"
                    required
                    value={formState.fullName}
                    onChange={(e) => setFormState({ ...formState, fullName: e.target.value })}
                    placeholder="e.g. Ramesh Kumar"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Username (Admin Managed)
                  </label>
                  <input
                    type="text"
                    value={formState.username || ''}
                    onChange={(e) => setFormState({ ...formState, username: e.target.value.toLowerCase().replace(/\s+/g, '') })}
                    placeholder="e.g. ramesh_dealer"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                  <span className="text-[10px] text-slate-400 block mt-0.5 font-medium">
                    Set exclusively by Super Admin. Buyers cannot edit their username.
                  </span>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Mobile Number (Login & OTP) *</label>
                  <input
                    type="tel"
                    required
                    value={formState.phone}
                    onChange={(e) => setFormState({ ...formState, phone: e.target.value })}
                    placeholder="e.g. +91 9876543210"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Email Address</label>
                  <input
                    type="email"
                    value={formState.email}
                    onChange={(e) => setFormState({ ...formState, email: e.target.value })}
                    placeholder="e.g. ramesh@aquastore.in"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    {formMode === 'create' ? 'Initial Password' : 'Set / Reset Password'}
                  </label>
                  <input
                    type="password"
                    value={formState.password || ''}
                    onChange={(e) => setFormState({ ...formState, password: e.target.value })}
                    placeholder={formMode === 'create' ? 'Default: GrandAqua@Buyer2026' : 'Leave blank to keep unchanged'}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                  {formMode === 'edit' && (
                    <span className="text-[10px] text-slate-400 block mt-0.5">
                      Enter a new password here if you want to reset this buyer's credentials.
                    </span>
                  )}
                </div>
              </div>

              {/* 3. BUSINESS & TRADE DETAILS */}
              <div className="flex flex-col gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Business / Shop Name *</label>
                  <input
                    type="text"
                    required
                    value={formState.businessName}
                    onChange={(e) => setFormState({ ...formState, businessName: e.target.value })}
                    placeholder="e.g. Aqua Pure Systems & Spares"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Business Type</label>
                  <input
                    type="text"
                    value={formState.businessType}
                    onChange={(e) => setFormState({ ...formState, businessType: e.target.value })}
                    placeholder="e.g. Retail Shop / Hardware / Plumber"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">GSTIN (Optional)</label>
                  <input
                    type="text"
                    value={formState.gstin}
                    onChange={(e) => setFormState({ ...formState, gstin: e.target.value.toUpperCase() })}
                    placeholder="32AAAAA0000A1Z5"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {/* 4. CATEGORY & LOYALTY TIER */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 bg-sky-50/40 rounded-xl border border-sky-100">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Buyer Category (Pricing Tier)</label>
                  <select
                    value={formState.buyerType}
                    onChange={(e) => setFormState({ ...formState, buyerType: e.target.value })}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value="CUSTOMER">CUSTOMER (Retail Price)</option>
                    <option value="DEALER">DEALER (Shop / Retailer Discount)</option>
                    <option value="WHOLESALER">WHOLESALER (Bulk Price)</option>
                    <option value="DISTRIBUTOR">DISTRIBUTOR (Stockist Price)</option>
                  </select>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Loyalty Tier (Gold, Diamond, Platinum)
                  </label>
                  <select
                    value={formState.loyaltyTier}
                    onChange={(e) => setFormState({ ...formState, loyaltyTier: e.target.value })}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-bold text-amber-700 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value="NONE">Standard (None)</option>
                    <option value="GOLD">🥇 GOLD TIER</option>
                    <option value="DIAMOND">💎 DIAMOND TIER</option>
                    <option value="PLATINUM">🏆 PLATINUM TIER</option>
                  </select>
                </div>
              </div>

              {/* 5. CREDIT & FINANCIAL TERMS */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 p-3 bg-teal-50/40 rounded-xl border border-teal-100">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Credit Limit (₹)</label>
                  <input
                    type="number"
                    min="0"
                    step="1000"
                    value={formState.creditLimit}
                    onChange={(e) => setFormState({ ...formState, creditLimit: Number(e.target.value) })}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-teal-800 focus:outline-none focus:ring-2 focus:ring-teal-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Credit Due Terms (Days)</label>
                  <input
                    type="number"
                    min="0"
                    max="180"
                    value={formState.creditDays}
                    onChange={(e) => setFormState({ ...formState, creditDays: Number(e.target.value) })}
                    placeholder="e.g. 30"
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-teal-800 focus:outline-none focus:ring-2 focus:ring-teal-500"
                  />
                  <span className="text-[10px] text-slate-400 mt-0.5 block">
                    Used to calculate overdue timeline & days left for payment.
                  </span>
                </div>
              </div>

              {/* 6. ASSIGNED SALESMAN */}
              <div>
                <label className="block font-bold text-slate-700 mb-1">Assigned Sales Representative</label>
                <select
                  value={formState.assignedSalesmanId}
                  onChange={(e) => setFormState({ ...formState, assignedSalesmanId: e.target.value })}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="">Unassigned (None)</option>
                  {salesmen.map((s: any) => (
                    <option key={s.id} value={s.id}>
                      {s.user?.fullName || 'Salesman'} ({s.employeeCode || s.id}) - {s.territory || 'General'}
                    </option>
                  ))}
                </select>
              </div>

              {/* 7. ADDRESS */}
              <div className="flex flex-col gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Billing / Shop Address</label>
                  <input
                    type="text"
                    value={formState.billingAddress}
                    onChange={(e) => setFormState({ ...formState, billingAddress: e.target.value })}
                    placeholder="Shop No, Street, Landmark"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">District / City</label>
                  <input
                    type="text"
                    value={formState.district}
                    onChange={(e) => setFormState({ ...formState, district: e.target.value })}
                    placeholder="Ernakulam"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">State</label>
                  <input
                    type="text"
                    value={formState.state}
                    onChange={(e) => setFormState({ ...formState, state: e.target.value })}
                    placeholder="Kerala"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">PIN Code</label>
                  <input
                    type="text"
                    value={formState.pinCode}
                    onChange={(e) => setFormState({ ...formState, pinCode: e.target.value })}
                    placeholder="682001"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:bg-white focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {/* Modal Buttons */}
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsFormModalOpen(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createMutation.isPending || updateMutation.isPending}
                  className="px-5 py-2.5 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50 flex items-center gap-2 cursor-pointer"
                >
                  {(createMutation.isPending || updateMutation.isPending) && (
                    <Loader2 className="w-4 h-4 animate-spin" />
                  )}
                  <span>{formMode === 'create' ? 'Create Buyer Account' : 'Save Changes'}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* COMPLETE BUYER PROFILE & HISTORY MODAL */}
      {selectedBuyerId && buyerDetail && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 max-h-[90vh] overflow-y-auto space-y-5">
            {/* Modal Header */}
            <div className="flex items-start justify-between border-b border-slate-100 pb-4">
              <div className="flex items-center gap-4">
                {buyerDetail.ownerPhoto || buyerDetail.user?.profilePhoto ? (
                  <img
                    src={buyerDetail.ownerPhoto || buyerDetail.user?.profilePhoto}
                    alt="Owner"
                    className="w-16 h-16 rounded-full object-cover border-2 border-sky-500 shadow-md flex-shrink-0"
                  />
                ) : (
                  <div className="w-16 h-16 rounded-full bg-sky-100 text-sky-800 font-black flex items-center justify-center border-2 border-sky-300 flex-shrink-0 text-xl">
                    {(buyerDetail.businessName || buyerDetail.user?.fullName || 'B').charAt(0).toUpperCase()}
                  </div>
                )}
                <div>
                  <div className="flex items-center gap-2 flex-wrap">
                    <h2 className="text-lg font-black text-slate-900">
                      {buyerDetail.businessName || buyerDetail.user?.fullName}
                    </h2>
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-sky-100 text-sky-800 uppercase">
                      {buyerDetail.buyerType}
                    </span>
                    <span
                      className={`px-2 py-0.5 rounded text-[10px] font-bold border ${
                        buyerDetail.loyaltyTier === 'DIAMOND'
                          ? 'bg-sky-50 text-sky-700 border-sky-300'
                          : buyerDetail.loyaltyTier === 'GOLD'
                          ? 'bg-amber-50 text-amber-700 border-amber-300'
                          : buyerDetail.loyaltyTier === 'PLATINUM'
                          ? 'bg-purple-50 text-purple-700 border-purple-300'
                          : 'bg-slate-100 text-slate-600 border-slate-200'
                      }`}
                    >
                      {buyerDetail.loyaltyTier === 'NONE' ? 'Standard Tier' : `${buyerDetail.loyaltyTier} Tier`}
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 font-mono mt-0.5">
                    Buyer Code: <strong>{buyerDetail.buyerId}</strong> • Contact: {buyerDetail.user?.fullName} ({buyerDetail.user?.phone})
                  </p>
                </div>
              </div>

              <button
                onClick={() => setSelectedBuyerId(null)}
                className="text-slate-400 hover:text-slate-600 p-1 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Quick Loyalty Tier Actions Bar */}
            <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3 text-xs">
              <span className="font-bold text-slate-700 flex items-center gap-1.5">
                <Award className="w-4 h-4 text-amber-500" />
                Change Loyalty Tier:
              </span>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  onClick={() => loyaltyTierMutation.mutate({ id: buyerDetail.id, newTier: 'GOLD' })}
                  className={`px-2.5 py-1 rounded-lg font-bold border transition-all ${
                    buyerDetail.loyaltyTier === 'GOLD'
                      ? 'bg-amber-500 text-white border-amber-600 shadow-sm'
                      : 'bg-amber-50 text-amber-800 border-amber-300 hover:bg-amber-100'
                  }`}
                >
                  🥇 Make Gold
                </button>
                <button
                  onClick={() => loyaltyTierMutation.mutate({ id: buyerDetail.id, newTier: 'DIAMOND' })}
                  className={`px-2.5 py-1 rounded-lg font-bold border transition-all ${
                    buyerDetail.loyaltyTier === 'DIAMOND'
                      ? 'bg-sky-500 text-white border-sky-600 shadow-sm'
                      : 'bg-sky-50 text-sky-800 border-sky-300 hover:bg-sky-100'
                  }`}
                >
                  💎 Make Diamond
                </button>
                <button
                  onClick={() => loyaltyTierMutation.mutate({ id: buyerDetail.id, newTier: 'PLATINUM' })}
                  className={`px-2.5 py-1 rounded-lg font-bold border transition-all ${
                    buyerDetail.loyaltyTier === 'PLATINUM'
                      ? 'bg-purple-600 text-white border-purple-700 shadow-sm'
                      : 'bg-purple-50 text-purple-800 border-purple-300 hover:bg-purple-100'
                  }`}
                >
                  🏆 Make Platinum
                </button>
                <button
                  onClick={() => loyaltyTierMutation.mutate({ id: buyerDetail.id, newTier: 'NONE' })}
                  className={`px-2.5 py-1 rounded-lg font-bold border transition-all ${
                    buyerDetail.loyaltyTier === 'NONE'
                      ? 'bg-slate-700 text-white border-slate-800'
                      : 'bg-slate-100 text-slate-700 border-slate-300 hover:bg-slate-200'
                  }`}
                >
                  Standard
                </button>
              </div>
            </div>

            {/* Financial & Dues Summary Card */}
            {buyerDetail.dueSummary && (
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
                <div className="p-3 bg-teal-50/60 rounded-xl border border-teal-100">
                  <span className="text-[10px] text-teal-700 font-bold uppercase tracking-wider">Credit Limit</span>
                  <p className="text-base font-black text-teal-900 mt-0.5 font-mono">
                    ₹{Number(buyerDetail.dueSummary.creditLimit).toLocaleString('en-IN')}
                  </p>
                  <span className="text-[10px] text-slate-500">
                    Terms: {buyerDetail.dueSummary.paymentTermsDays || 30} Days
                  </span>
                </div>

                <div className="p-3 bg-emerald-50/60 rounded-xl border border-emerald-100">
                  <span className="text-[10px] text-emerald-700 font-bold uppercase tracking-wider">Available Balance</span>
                  <p className="text-base font-black text-emerald-900 mt-0.5 font-mono">
                    ₹{Number(buyerDetail.dueSummary.availableCredit).toLocaleString('en-IN')}
                  </p>
                  <span className="text-[10px] text-emerald-600 font-bold">Approved Facility</span>
                </div>

                <div className="p-3 bg-rose-50/60 rounded-xl border border-rose-100">
                  <span className="text-[10px] text-rose-700 font-bold uppercase tracking-wider">Outstanding Amount</span>
                  <p className="text-base font-black text-rose-900 mt-0.5 font-mono">
                    ₹{Number(buyerDetail.dueSummary.outstandingAmount).toLocaleString('en-IN')}
                  </p>
                  <span className="text-[10px] text-rose-600 font-bold">Unpaid Dues</span>
                </div>

                <div className="p-3 bg-amber-50/60 rounded-xl border border-amber-100">
                  <span className="text-[10px] text-amber-700 font-bold uppercase tracking-wider">Due Timeline</span>
                  <p className="text-xs font-black text-amber-900 mt-1">
                    {buyerDetail.dueSummary.statusText}
                  </p>
                  {buyerDetail.dueSummary.dueDate && (
                    <span className="text-[10px] text-slate-500 font-mono">
                      Due: {new Date(buyerDetail.dueSummary.dueDate).toLocaleDateString('en-IN')}
                    </span>
                  )}
                </div>
              </div>
            )}

            {/* Profile Navigation Tabs */}
            <div className="flex border-b border-slate-200 gap-4 text-xs font-bold">
              <button
                onClick={() => setProfileActiveTab('purchases')}
                className={`pb-2.5 flex items-center gap-1.5 transition-all cursor-pointer ${
                  profileActiveTab === 'purchases'
                    ? 'border-b-2 border-sky-600 text-sky-700'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                <Package className="w-4 h-4" />
                Purchase History ({buyerDetail.orders?.length || 0})
              </button>

              <button
                onClick={() => setProfileActiveTab('payments')}
                className={`pb-2.5 flex items-center gap-1.5 transition-all cursor-pointer ${
                  profileActiveTab === 'payments'
                    ? 'border-b-2 border-sky-600 text-sky-700'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                <CreditCard className="w-4 h-4" />
                Payment History ({buyerDetail.payments?.length || 0})
              </button>

              <button
                onClick={() => setProfileActiveTab('info')}
                className={`pb-2.5 flex items-center gap-1.5 transition-all cursor-pointer ${
                  profileActiveTab === 'info'
                    ? 'border-b-2 border-sky-600 text-sky-700'
                    : 'text-slate-500 hover:text-slate-800'
                }`}
              >
                <Store className="w-4 h-4" />
                Shop & Trade Profile
              </button>
            </div>

            {/* TAB CONTENT 1: PURCHASE HISTORY (INCLUDING PRODUCTS) */}
            {profileActiveTab === 'purchases' && (
              <div className="space-y-4">
                {buyerDetail.orders && buyerDetail.orders.length > 0 ? (
                  buyerDetail.orders.map((ord: any) => (
                    <div
                      key={ord.id}
                      className="p-4 bg-slate-50 rounded-xl border border-slate-200 text-xs space-y-3"
                    >
                      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-2 border-b border-slate-200 pb-2">
                        <div>
                          <span className="font-mono font-bold text-sky-700 text-sm">
                            {ord.orderNumber || ord.id}
                          </span>
                          <span className="text-slate-400 text-[11px] ml-2">
                            {new Date(ord.createdAt).toLocaleDateString('en-IN', {
                              day: 'numeric',
                              month: 'short',
                              year: 'numeric',
                            })}
                          </span>
                        </div>
                        <div className="flex items-center gap-2">
                          <span className="px-2 py-0.5 bg-slate-200 font-bold rounded text-[10px] uppercase text-slate-700">
                            {ord.status}
                          </span>
                          <span
                            className={`px-2 py-0.5 rounded text-[10px] font-bold ${
                              ord.paymentStatus === 'PAID'
                                ? 'bg-emerald-100 text-emerald-800'
                                : 'bg-rose-100 text-rose-800'
                            }`}
                          >
                            {ord.paymentStatus}
                          </span>
                          <span className="font-mono font-black text-slate-900 text-sm">
                            ₹{Number(ord.finalAmount || 0).toLocaleString('en-IN')}
                          </span>
                        </div>
                      </div>

                      {/* Products List in this Order */}
                      <div>
                        <span className="font-bold text-slate-700 block mb-1 text-[11px]">
                          Purchased Products ({ord.items?.length || 0}):
                        </span>
                        {ord.items && ord.items.length > 0 ? (
                          <div className="overflow-x-auto bg-white rounded-lg border border-slate-200">
                            <table className="w-full text-left text-[11px]">
                              <thead className="bg-slate-100/70 border-b border-slate-200 text-slate-600 font-bold">
                                <tr>
                                  <th className="px-3 py-1.5">Product Name</th>
                                  <th className="px-3 py-1.5">SKU</th>
                                  <th className="px-3 py-1.5 text-center">Qty</th>
                                  <th className="px-3 py-1.5 text-right">Unit Price</th>
                                  <th className="px-3 py-1.5 text-right">Total</th>
                                </tr>
                              </thead>
                              <tbody className="divide-y divide-slate-100">
                                {ord.items.map((item: any) => (
                                  <tr key={item.id} className="hover:bg-slate-50">
                                    <td className="px-3 py-1.5 font-semibold text-slate-900">
                                      {item.product?.name || item.productName || 'Grand Aqua Product'}
                                    </td>
                                    <td className="px-3 py-1.5 font-mono text-slate-500">
                                      {item.product?.sku || item.sku || 'N/A'}
                                    </td>
                                    <td className="px-3 py-1.5 text-center font-bold">
                                      {item.quantity}
                                    </td>
                                    <td className="px-3 py-1.5 text-right font-mono">
                                      ₹{Number(item.unitPrice || 0).toLocaleString('en-IN')}
                                    </td>
                                    <td className="px-3 py-1.5 text-right font-mono font-bold text-slate-900">
                                      ₹{Number(item.totalPrice || item.quantity * item.unitPrice || 0).toLocaleString('en-IN')}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        ) : (
                          <p className="text-slate-400 italic text-[11px]">Standard order package</p>
                        )}
                      </div>
                    </div>
                  ))
                ) : (
                  <div className="text-center py-8 text-slate-400 bg-slate-50 rounded-xl border border-dashed border-slate-200">
                    <Package className="w-8 h-8 mx-auto mb-2 opacity-40" />
                    <p>No purchase records or order history registered for this buyer yet.</p>
                  </div>
                )}
              </div>
            )}

            {/* TAB CONTENT 2: PAYMENT HISTORY */}
            {profileActiveTab === 'payments' && (
              <div className="space-y-3">
                {buyerDetail.payments && buyerDetail.payments.length > 0 ? (
                  <div className="overflow-x-auto bg-white rounded-xl border border-slate-200">
                    <table className="w-full text-left text-xs">
                      <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider text-[11px]">
                        <tr>
                          <th className="px-4 py-2.5">Receipt #</th>
                          <th className="px-4 py-2.5">Payment Date</th>
                          <th className="px-4 py-2.5">Amount (₹)</th>
                          <th className="px-4 py-2.5">Method</th>
                          <th className="px-4 py-2.5">Transaction Ref</th>
                          <th className="px-4 py-2.5">Status</th>
                        </tr>
                      </thead>
                      <tbody className="divide-y divide-slate-100">
                        {buyerDetail.payments.map((pay: any) => (
                          <tr key={pay.id} className="hover:bg-slate-50">
                            <td className="px-4 py-2.5 font-mono font-bold text-sky-700">
                              {pay.paymentNumber || pay.id.substring(0, 8)}
                            </td>
                            <td className="px-4 py-2.5 text-slate-600">
                              {new Date(pay.paymentDate || pay.createdAt).toLocaleDateString('en-IN', {
                                day: 'numeric',
                                month: 'short',
                                year: 'numeric',
                              })}
                            </td>
                            <td className="px-4 py-2.5 font-mono font-black text-emerald-700">
                              ₹{Number(pay.amount).toLocaleString('en-IN')}
                            </td>
                            <td className="px-4 py-2.5">
                              <span className="px-2 py-0.5 bg-slate-100 rounded text-[10px] font-bold">
                                {pay.paymentMethod || 'BANK_TRANSFER'}
                              </span>
                            </td>
                            <td className="px-4 py-2.5 font-mono text-[11px] text-slate-500">
                              {pay.transactionReference || 'N/A'}
                            </td>
                            <td className="px-4 py-2.5">
                              <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-100 text-emerald-800">
                                {pay.paymentStatus || 'PAID'}
                              </span>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                ) : (
                  <div className="text-center py-8 text-slate-400 bg-slate-50 rounded-xl border border-dashed border-slate-200">
                    <CreditCard className="w-8 h-8 mx-auto mb-2 opacity-40" />
                    <p>No payment settlements recorded yet.</p>
                  </div>
                )}
              </div>
            )}

            {/* TAB CONTENT 3: SHOP & PROFILE INFO */}
            {profileActiveTab === 'info' && (
              <div className="space-y-4 text-xs">
                {buyerDetail.shopPhoto && (
                  <div className="rounded-xl overflow-hidden border border-slate-200 max-h-56">
                    <img
                      src={buyerDetail.shopPhoto}
                      alt="Shop Storefront"
                      className="w-full h-full object-cover"
                    />
                  </div>
                )}

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="p-3 bg-slate-50 rounded-xl space-y-1">
                    <span className="text-slate-400 text-[10px] uppercase font-bold">Business Name</span>
                    <p className="font-bold text-slate-800 text-sm">{buyerDetail.businessName}</p>
                    <p className="text-slate-500">{buyerDetail.businessType || 'Retailer'}</p>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl space-y-1">
                    <span className="text-slate-400 text-[10px] uppercase font-bold">GSTIN Registration</span>
                    <p className="font-mono font-bold text-slate-800 text-sm">
                      {buyerDetail.gstin || 'Not Provided / Unregistered'}
                    </p>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl space-y-1">
                    <span className="text-slate-400 text-[10px] uppercase font-bold">Billing Address</span>
                    <p className="font-medium text-slate-700">
                      {buyerDetail.billingAddress || 'No address provided'}
                    </p>
                    <p className="text-slate-500 font-mono">
                      {buyerDetail.district}, {buyerDetail.state} - {buyerDetail.pinCode}
                    </p>
                  </div>

                  <div className="p-3 bg-slate-50 rounded-xl space-y-1">
                    <span className="text-slate-400 text-[10px] uppercase font-bold">Assigned Sales Representative</span>
                    <p className="font-bold text-slate-800">
                      {buyerDetail.assignedSalesman?.user?.fullName || 'Unassigned'}
                    </p>
                    <p className="text-slate-500 font-mono">
                      {buyerDetail.assignedSalesman?.employeeCode || ''}
                    </p>
                  </div>
                </div>
              </div>
            )}

            {/* Bottom Close */}
            <div className="flex justify-end pt-3 border-t border-slate-100">
              <button
                onClick={() => setSelectedBuyerId(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold rounded-xl"
              >
                Close Profile
              </button>
            </div>
          </div>
        </div>
      )}

      {/* CONFIRM DELETE DIALOG */}
      {deleteConfirmId && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl border border-slate-100 space-y-3">
            <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mx-auto">
              <Trash2 className="w-6 h-6" />
            </div>
            <div className="text-center">
              <h3 className="font-bold text-slate-900">Delete Buyer Profile?</h3>
              <p className="text-xs text-slate-500 mt-1">
                Are you sure you want to permanently delete this buyer account and linked trade records?
              </p>
            </div>
            <div className="flex items-center justify-end gap-2 pt-2">
              <button
                onClick={() => setDeleteConfirmId(null)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                onClick={() => deleteMutation.mutate(deleteConfirmId)}
                disabled={deleteMutation.isPending}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {deleteMutation.isPending ? 'Deleting...' : 'Confirm Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* CONFIRM CATEGORY PROMOTE DIALOG */}
      {promoteModalBuyer && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-base font-bold text-slate-900">Change Buyer Category</h2>
              <button
                onClick={() => setPromoteModalBuyer(null)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-amber-800 text-xs space-y-1">
              <div className="font-bold flex items-center gap-1.5">
                <AlertTriangle className="w-4 h-4 text-amber-600" />
                Commercial & Financial Notice:
              </div>
              <ul className="list-disc pl-5 space-y-0.5 text-[11px]">
                <li>Future quotations & direct app orders will use the new category price snapshot.</li>
                <li>Credit eligibility guidelines will adjust to the new category requirements.</li>
                <li>An audit record and notification will be sent to the buyer.</li>
              </ul>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Target Category</label>
                <select
                  value={newType}
                  onChange={(e) => setNewType(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="CUSTOMER">Customer (Retail Pricing)</option>
                  <option value="DEALER">Dealer / Retailer</option>
                  <option value="WHOLESALER">Wholesaler</option>
                  <option value="DISTRIBUTOR">Distributor (Max Concession)</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Authorization Reason *</label>
                <textarea
                  required
                  rows={3}
                  value={promoteReason}
                  onChange={(e) => setPromoteReason(e.target.value)}
                  placeholder="e.g. Verified trade GSTIN, completed annual purchase milestone..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500"
                ></textarea>
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setPromoteModalBuyer(null)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!promoteReason.trim() || promoteMutation.isPending}
                onClick={() =>
                  promoteMutation.mutate({
                    id: promoteModalBuyer.id,
                    newType,
                    reason: promoteReason,
                  })
                }
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {promoteMutation.isPending ? 'Updating...' : 'Confirm Category Change'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
