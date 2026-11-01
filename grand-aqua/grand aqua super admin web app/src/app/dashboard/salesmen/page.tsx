'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Users,
  Plus,
  Search,
  Phone,
  Mail,
  MapPin,
  Calendar,
  DollarSign,
  TrendingUp,
  Award,
  ShieldAlert,
  ShieldCheck,
  Edit2,
  Trash2,
  Ban,
  CheckCircle,
  Eye,
  ShoppingBag,
  Store,
  UserCheck,
  X,
  Filter,
  Layers,
  ArrowRight,
  Upload,
  Loader2,
  Camera,
} from 'lucide-react';

interface SalesmanFormState {
  isOpen: boolean;
  mode: 'create' | 'edit';
  id?: string;
  fullName: string;
  username: string;
  phone: string;
  email: string;
  designation: string;
  assignedTerritory: string;
  address: string;
  password?: string;
  imageUrl: string;
}

const initialFormState: SalesmanFormState = {
  isOpen: false,
  mode: 'create',
  fullName: '',
  username: '',
  phone: '',
  email: '',
  designation: 'Area Sales Executive',
  assignedTerritory: 'North Region',
  address: '',
  password: '',
  imageUrl: '',
};

export default function SalesmenPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState<'ALL' | 'ACTIVE' | 'BLOCKED'>('ALL');
  const [formModal, setFormModal] = useState<SalesmanFormState>(initialFormState);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Assigned Buyers Modal State
  const [viewingBuyersSalesman, setViewingBuyersSalesman] = useState<any>(null);
  const [assignBuyerId, setAssignBuyerId] = useState('');

  // Sales History Modal State with Filters
  const [historySalesman, setHistorySalesman] = useState<any>(null);
  const [historyStartDate, setHistoryStartDate] = useState('');
  const [historyEndDate, setHistoryEndDate] = useState('');
  const [historyBuyerId, setHistoryBuyerId] = useState('');

  // 1. Fetch Salesmen
  const { data: salesmenData, isLoading } = useQuery({
    queryKey: ['salesmen-list'],
    queryFn: () => api.get('/salesmen'),
  });
  const salesmenList = Array.isArray(salesmenData)
    ? salesmenData
    : (salesmenData as any)?.data || [];

  // 2. Fetch All Buyers for Assignment Dropdown
  const { data: allBuyersData } = useQuery({
    queryKey: ['all-buyers-dropdown'],
    queryFn: () => api.get('/buyers?limit=100'),
  });
  const allBuyers = (allBuyersData as any)?.buyers || (Array.isArray(allBuyersData) ? allBuyersData : []);

  // 3. Fetch Assigned Buyers for Active Modal
  const { data: assignedBuyersData, refetch: refetchAssignedBuyers } = useQuery({
    queryKey: ['salesman-assigned-buyers', viewingBuyersSalesman?.id],
    queryFn: () => api.get(`/salesmen/${viewingBuyersSalesman.id}/buyers`),
    enabled: !!viewingBuyersSalesman,
  });
  const assignedBuyers = Array.isArray(assignedBuyersData) ? assignedBuyersData : [];

  // 4. Fetch Sales History with Date & Buyer filters
  const { data: salesHistoryData, isLoading: isHistoryLoading, refetch: refetchHistory } = useQuery({
    queryKey: ['salesman-history', historySalesman?.id, historyStartDate, historyEndDate, historyBuyerId],
    queryFn: () => {
      let url = `/salesmen/${historySalesman.id}/sales-history?limit=100`;
      if (historyStartDate) url += `&startDate=${historyStartDate}`;
      if (historyEndDate) url += `&endDate=${historyEndDate}`;
      if (historyBuyerId) url += `&buyerProfileId=${historyBuyerId}`;
      return api.get(url);
    },
    enabled: !!historySalesman,
  });
  const historyOrders = (salesHistoryData as any)?.orders || [];
  const historySummary = (salesHistoryData as any)?.summary || {
    totalOrders: 0,
    totalSales: 0,
    totalPaid: 0,
    totalOutstanding: 0,
    deliveredCount: 0,
    provisionalCommission: 0,
  };

  // Mutations
  const createSalesmanMutation = useMutation({
    mutationFn: (payload: any) => api.post('/salesmen', payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      setFormModal(initialFormState);
      alert('Sales representative created successfully!');
    },
    onError: (err: any) => alert(`Error creating salesman: ${err.message}`),
  });

  const updateSalesmanMutation = useMutation({
    mutationFn: (vars: any) => api.put(`/salesmen/${vars.id}`, vars.payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      setFormModal(initialFormState);
      alert('Salesman updated successfully!');
    },
    onError: (err: any) => alert(`Error updating salesman: ${err.message}`),
  });

  const toggleBlockMutation = useMutation({
    mutationFn: (id: string) => api.put(`/salesmen/${id}/toggle-block`, {}),
    onSuccess: (data: any) => {
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      alert(data.message || 'Salesman status updated!');
    },
    onError: (err: any) => alert(`Error toggling block: ${err.message}`),
  });

  const deleteSalesmanMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/salesmen/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      setDeleteConfirmId(null);
      alert('Salesman removed successfully.');
    },
    onError: (err: any) => alert(`Error deleting salesman: ${err.message}`),
  });

  const assignBuyerMutation = useMutation({
    mutationFn: (vars: { salesmanId: string; buyerProfileId: string }) =>
      api.post(`/salesmen/${vars.salesmanId}/assign-buyer`, { buyerProfileId: vars.buyerProfileId }),
    onSuccess: () => {
      refetchAssignedBuyers();
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      setAssignBuyerId('');
      alert('Buyer successfully assigned to salesman!');
    },
    onError: (err: any) => alert(`Error assigning buyer: ${err.message}`),
  });

  const unassignBuyerMutation = useMutation({
    mutationFn: (vars: { salesmanId: string; buyerId: string }) =>
      api.delete(`/salesmen/${vars.salesmanId}/unassign-buyer/${vars.buyerId}`),
    onSuccess: () => {
      refetchAssignedBuyers();
      queryClient.invalidateQueries({ queryKey: ['salesmen-list'] });
      alert('Buyer unassigned successfully.');
    },
    onError: (err: any) => alert(`Error unassigning buyer: ${err.message}`),
  });

  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);

  const handleImageUpload = async (file: File) => {
    if (!file) return;
    setUploadingImage(true);
    setUploadError(null);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const res: any = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const url = res.url || res.relativePath || res.data?.url || res.data?.relativePath;
      if (url) {
        setFormModal((prev) => ({ ...prev, imageUrl: url }));
      }
    } catch (err: any) {
      setUploadError(`Failed to upload photo: ${err.message}`);
    } finally {
      setUploadingImage(false);
    }
  };

  const openCreateModal = () => {
    setUploadError(null);
    setFormModal({
      ...initialFormState,
      isOpen: true,
      mode: 'create',
    });
  };

  const openEditModal = (sm: any) => {
    setUploadError(null);
    setFormModal({
      isOpen: true,
      mode: 'edit',
      id: sm.id,
      fullName: sm.user?.fullName || '',
      username: sm.user?.username || '',
      phone: sm.user?.phone || '',
      email: sm.user?.email || '',
      designation: sm.assignedTerritory || 'Area Sales Executive',
      assignedTerritory: sm.assignedTerritory || '',
      address: sm.address || '',
      imageUrl: sm.user?.profilePhoto || '',
    });
  };

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formModal.fullName.trim() || !formModal.phone.trim()) {
      alert('Full Name and Mobile Number are required.');
      return;
    }

    const payload: any = {
      fullName: formModal.fullName.trim(),
      username: formModal.username.trim() || undefined,
      phone: formModal.phone.trim(),
      email: formModal.email.trim() || undefined,
      designation: formModal.designation.trim(),
      assignedTerritory: formModal.assignedTerritory.trim(),
      address: formModal.address.trim() || undefined,
      password: formModal.password?.trim() || undefined,
      profilePhoto: formModal.imageUrl.trim() || undefined,
    };

    if (formModal.mode === 'create') {
      createSalesmanMutation.mutate(payload);
    } else if (formModal.id) {
      updateSalesmanMutation.mutate({ id: formModal.id, payload });
    }
  };

  const filteredSalesmen = salesmenList.filter((sm: any) => {
    const isBlocked = sm.user?.status === 'BLOCKED' || sm.employmentStatus === 'BLOCKED';
    if (statusFilter === 'ACTIVE' && isBlocked) return false;
    if (statusFilter === 'BLOCKED' && !isBlocked) return false;

    if (!search.trim()) return true;
    const term = search.toLowerCase();
    const name = (sm.user?.fullName || '').toLowerCase();
    const username = (sm.user?.username || '').toLowerCase();
    const code = (sm.employeeCode || '').toLowerCase();
    const phone = (sm.user?.phone || '').toLowerCase();
    const territory = (sm.assignedTerritory || '').toLowerCase();
    return name.includes(term) || username.includes(term) || code.includes(term) || phone.includes(term) || territory.includes(term);
  });

  return (
    <div className="space-y-6">
      {/* Top Banner & Main Actions */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <Users className="w-6 h-6 text-sky-600" />
            Salesman Management
          </h1>
          <p className="text-sm text-slate-500">
            Full sales staff CRUD, territory assignment, block/unblock control, assigned buyer networks, and filtered sales history.
          </p>
        </div>

        <button
          onClick={openCreateModal}
          className="px-4 py-2.5 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md flex items-center gap-1.5 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>Register New Salesman</span>
        </button>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search name, mobile, code, territory..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
          />
        </div>

        {/* Status Filters */}
        <div className="flex items-center gap-2">
          {(['ALL', 'ACTIVE', 'BLOCKED'] as const).map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3 py-1.5 text-xs font-bold rounded-xl transition-all ${
                statusFilter === st
                  ? st === 'BLOCKED'
                    ? 'bg-rose-600 text-white shadow-sm'
                    : 'bg-sky-600 text-white shadow-sm'
                  : 'bg-slate-50 text-slate-600 hover:bg-slate-100 border border-slate-200'
              }`}
            >
              {st === 'ALL' ? 'All Salesmen' : st}
            </button>
          ))}
          <span className="text-xs text-slate-400 font-mono ml-2">
            Total: <strong>{filteredSalesmen.length}</strong>
          </span>
        </div>
      </div>

      {/* Salesmen Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="col-span-full py-16 text-center text-slate-400">Loading sales team...</div>
        ) : filteredSalesmen.length === 0 ? (
          <div className="col-span-full py-16 text-center bg-white rounded-2xl border border-dashed border-slate-300 p-8">
            <Users className="w-12 h-12 text-slate-300 mx-auto mb-2" />
            <h3 className="font-bold text-slate-700 text-sm">No sales representatives found</h3>
            <p className="text-xs text-slate-500 mt-1">Register field sales personnel to start assigning dealer networks.</p>
            <button
              onClick={openCreateModal}
              className="mt-4 px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl"
            >
              Add First Salesman
            </button>
          </div>
        ) : (
          filteredSalesmen.map((sm: any) => {
            const isBlocked = sm.user?.status === 'BLOCKED' || sm.employmentStatus === 'BLOCKED';

            return (
              <div
                key={sm.id}
                className={`bg-white rounded-2xl border p-6 shadow-sm flex flex-col justify-between hover:shadow-md transition-all ${
                  isBlocked ? 'border-rose-200 bg-rose-50/20' : 'border-slate-200'
                }`}
              >
                <div className="space-y-4">
                  {/* Card Header */}
                  <div className="flex items-start justify-between">
                    <div className="flex items-center gap-3">
                      {/* Avatar */}
                      <div className="w-12 h-12 rounded-full overflow-hidden border border-slate-200 bg-slate-100 flex items-center justify-center shrink-0 shadow-xs">
                        {sm.user?.profilePhoto ? (
                          <img
                            src={
                              sm.user.profilePhoto.startsWith('http')
                                ? sm.user.profilePhoto
                                : `http://192.168.29.44:4000${sm.user.profilePhoto.startsWith('/') ? '' : '/'}${sm.user.profilePhoto}`
                            }
                            alt={sm.user?.fullName}
                            className="w-full h-full object-cover"
                            onError={(e: any) => {
                              e.target.style.display = 'none';
                            }}
                          />
                        ) : null}
                        {!sm.user?.profilePhoto && (
                          <span className="font-extrabold text-sm text-sky-700 uppercase">
                            {sm.user?.fullName?.substring(0, 2) || 'SL'}
                          </span>
                        )}
                      </div>

                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="font-extrabold text-slate-900 text-base">{sm.user?.fullName}</h3>
                        {isBlocked ? (
                          <span className="px-2 py-0.5 bg-rose-100 text-rose-700 font-bold text-[9px] rounded-full uppercase flex items-center gap-1 border border-rose-200">
                            <Ban className="w-2.5 h-2.5" /> Blocked
                          </span>
                        ) : (
                          <span className="px-2 py-0.5 bg-emerald-100 text-emerald-800 font-bold text-[9px] rounded-full uppercase flex items-center gap-1 border border-emerald-200">
                            <CheckCircle className="w-2.5 h-2.5" /> Active
                          </span>
                        )}
                      </div>
                      <div className="text-xs text-sky-600 font-mono font-bold mt-0.5 flex flex-wrap items-center gap-1">
                        <span>{sm.employeeCode}</span>
                        {sm.user?.username && (
                          <>
                            <span className="text-slate-300">•</span>
                            <span className="text-indigo-600 font-mono font-medium">@{sm.user.username}</span>
                          </>
                        )}
                        <span className="text-slate-300">•</span>
                        <span className="text-slate-500 font-sans font-medium">{sm.assignedTerritory || 'Area Sales'}</span>
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-1">
                      <button
                        onClick={() => openEditModal(sm)}
                        className="p-1.5 text-slate-500 hover:text-sky-600 hover:bg-sky-50 rounded-lg border border-slate-200 transition-all"
                        title="Edit Details"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => setDeleteConfirmId(sm.id)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 rounded-lg border border-slate-200 transition-all"
                        title="Delete Salesman"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Contact Info */}
                  <div className="space-y-1.5 text-xs text-slate-600 font-medium">
                    <div className="flex items-center gap-2">
                      <Phone className="w-3.5 h-3.5 text-slate-400" />
                      <a href={`tel:${sm.user?.phone}`} className="hover:text-sky-600 text-slate-800 font-mono">
                        {sm.user?.phone}
                      </a>
                    </div>
                    {sm.user?.email && (
                      <div className="flex items-center gap-2">
                        <Mail className="w-3.5 h-3.5 text-slate-400" />
                        <span className="truncate">{sm.user.email}</span>
                      </div>
                    )}
                    <div className="flex items-center gap-2">
                      <MapPin className="w-3.5 h-3.5 text-slate-400" />
                      <span>{sm.address || sm.assignedTerritory || 'Main Territory'}</span>
                    </div>
                  </div>

                  {/* Network Stats */}
                  <div className="p-3 bg-slate-50 rounded-xl border border-slate-100 flex items-center justify-between text-xs font-mono">
                    <div>
                      <span className="text-slate-400 text-[10px] font-bold uppercase font-sans">Assigned Buyers</span>
                      <p className="font-extrabold text-slate-900 text-base mt-0.5">
                        {sm._count?.assignedBuyers || sm.activeShopsCount || 0}
                      </p>
                    </div>
                    <div className="text-right">
                      <span className="text-slate-400 text-[10px] font-bold uppercase font-sans">Territory</span>
                      <p className="font-bold text-slate-700 text-xs mt-0.5 font-sans">
                        {sm.assignedTerritory || 'General'}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Card Action Buttons */}
                <div className="pt-4 mt-4 border-t border-slate-100 flex flex-col gap-2">
                  <div className="grid grid-cols-2 gap-2">
                    {/* View Assigned Buyers */}
                    <button
                      onClick={() => setViewingBuyersSalesman(sm)}
                      className="py-1.5 px-2 bg-sky-50 hover:bg-sky-100 text-sky-800 border border-sky-200 font-bold rounded-xl text-xs flex items-center justify-center gap-1 transition-all"
                    >
                      <Store className="w-3.5 h-3.5 text-sky-600" />
                      <span>Buyers ({sm._count?.assignedBuyers || sm.activeShopsCount || 0})</span>
                    </button>

                    {/* View Sales History */}
                    <button
                      onClick={() => {
                        setHistorySalesman(sm);
                        setHistoryStartDate('');
                        setHistoryEndDate('');
                        setHistoryBuyerId('');
                      }}
                      className="py-1.5 px-2 bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 font-bold rounded-xl text-xs flex items-center justify-center gap-1 transition-all"
                    >
                      <ShoppingBag className="w-3.5 h-3.5 text-emerald-600" />
                      <span>Sales History</span>
                    </button>
                  </div>

                  {/* Block / Unblock Button */}
                  <button
                    onClick={() => toggleBlockMutation.mutate(sm.id)}
                    className={`w-full py-1.5 text-xs font-bold rounded-xl border flex items-center justify-center gap-1.5 transition-all ${
                      isBlocked
                        ? 'bg-emerald-600 hover:bg-emerald-700 text-white border-emerald-600 shadow-sm'
                        : 'bg-rose-50 hover:bg-rose-100 text-rose-700 border-rose-200'
                    }`}
                  >
                    {isBlocked ? (
                      <>
                        <ShieldCheck className="w-3.5 h-3.5" />
                        <span>Unblock Salesman Access</span>
                      </>
                    ) : (
                      <>
                        <Ban className="w-3.5 h-3.5" />
                        <span>Block Salesman Access</span>
                      </>
                    )}
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* CREATE / EDIT SALESMAN MODAL */}
      {formModal.isOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-black text-slate-900 flex items-center gap-2">
                  <Users className="w-5 h-5 text-sky-600" />
                  {formModal.mode === 'create' ? 'Register New Salesman' : 'Edit Salesman Profile'}
                </h2>
                <p className="text-xs text-slate-500">Configure credentials, designation, territory, and sales targets.</p>
              </div>
              <button onClick={() => setFormModal(initialFormState)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleFormSubmit} className="space-y-3 text-xs">
              {/* Salesman Photo Upload */}
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-center gap-4">
                <div className="w-16 h-16 rounded-full overflow-hidden border-2 border-white shadow-xs bg-slate-200 shrink-0 flex items-center justify-center relative group">
                  {formModal.imageUrl ? (
                    <>
                      <img
                        src={
                          formModal.imageUrl.startsWith('http')
                            ? formModal.imageUrl
                            : `http://192.168.29.44:4000${formModal.imageUrl.startsWith('/') ? '' : '/'}${formModal.imageUrl}`
                        }
                        alt="Preview"
                        className="w-full h-full object-cover"
                        onError={(e: any) => {
                          e.target.style.display = 'none';
                        }}
                      />
                      <button
                        type="button"
                        onClick={() => setFormModal((prev) => ({ ...prev, imageUrl: '' }))}
                        className="absolute inset-0 bg-black/60 text-white flex items-center justify-center opacity-0 group-hover:opacity-100 transition text-[10px] font-bold"
                      >
                        Remove
                      </button>
                    </>
                  ) : (
                    <div className="flex flex-col items-center text-slate-400">
                      <Camera className="w-6 h-6 text-slate-400" />
                      <span className="text-[9px] mt-0.5">Photo</span>
                    </div>
                  )}
                </div>

                <div className="flex-1 space-y-1.5">
                  <div className="font-bold text-slate-700">Salesman Profile Photo</div>
                  <label className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-white border border-slate-300 hover:bg-slate-100 text-slate-700 rounded-lg text-xs font-bold cursor-pointer transition shadow-xs">
                    {uploadingImage ? (
                      <>
                        <Loader2 className="w-3.5 h-3.5 animate-spin" />
                        <span>Uploading...</span>
                      </>
                    ) : (
                      <>
                        <Upload className="w-3.5 h-3.5" />
                        <span>Choose Photo</span>
                      </>
                    )}
                    <input
                      type="file"
                      accept="image/*"
                      className="hidden"
                      disabled={uploadingImage}
                      onChange={(e) => {
                        const file = e.target.files?.[0];
                        if (file) handleImageUpload(file);
                      }}
                    />
                  </label>
                  {uploadError && <p className="text-[11px] text-rose-600 font-medium">{uploadError}</p>}
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Full Name *</label>
                  <input
                    type="text"
                    required
                    value={formModal.fullName}
                    onChange={(e) => setFormModal({ ...formModal, fullName: e.target.value })}
                    placeholder="e.g. Rahul Sharma"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Username (Optional)</label>
                  <input
                    type="text"
                    value={formModal.username}
                    onChange={(e) => setFormModal({ ...formModal, username: e.target.value.toLowerCase().replace(/\s+/g, '') })}
                    placeholder="e.g. rahul_sales"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Mobile Number *</label>
                  <input
                    type="tel"
                    required
                    value={formModal.phone}
                    onChange={(e) => setFormModal({ ...formModal, phone: e.target.value })}
                    placeholder="+919876543210"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Email (Optional)</label>
                  <input
                    type="email"
                    value={formModal.email}
                    onChange={(e) => setFormModal({ ...formModal, email: e.target.value })}
                    placeholder="salesman@grandaqua.com"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Designation</label>
                  <input
                    type="text"
                    value={formModal.designation}
                    onChange={(e) => setFormModal({ ...formModal, designation: e.target.value })}
                    placeholder="e.g. Territory Sales Manager"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Assigned Territory</label>
                  <input
                    type="text"
                    value={formModal.assignedTerritory}
                    onChange={(e) => setFormModal({ ...formModal, assignedTerritory: e.target.value })}
                    placeholder="e.g. Delhi South & Gurgaon"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {formModal.mode === 'create' && (
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Initial Password</label>
                  <input
                    type="text"
                    value={formModal.password}
                    onChange={(e) => setFormModal({ ...formModal, password: e.target.value })}
                    placeholder="GrandAqua@Sales2026 (Default if empty)"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              )}

              <div>
                <label className="block font-bold text-slate-700 mb-1">Address / Remarks</label>
                <textarea
                  rows={2}
                  value={formModal.address}
                  onChange={(e) => setFormModal({ ...formModal, address: e.target.value })}
                  placeholder="Base location, emergency contact, or field operational notes..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setFormModal(initialFormState)}
                  className="px-4 py-2 font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createSalesmanMutation.isPending || updateSalesmanMutation.isPending}
                  className="px-5 py-2.5 bg-sky-600 hover:bg-sky-700 text-white font-bold rounded-xl shadow-md disabled:opacity-50"
                >
                  {createSalesmanMutation.isPending || updateSalesmanMutation.isPending
                    ? 'Saving...'
                    : formModal.mode === 'create'
                    ? 'Register Salesman'
                    : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ASSIGNED BUYERS MODAL */}
      {viewingBuyersSalesman && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-black text-slate-900 flex items-center gap-2">
                  <Store className="w-5 h-5 text-sky-600" />
                  Assigned Buyers & Dealer Network
                </h2>
                <p className="text-xs text-slate-500 font-mono">
                  {viewingBuyersSalesman.employeeCode} • {viewingBuyersSalesman.user?.fullName} ({assignedBuyers.length} buyers)
                </p>
              </div>
              <button onClick={() => setViewingBuyersSalesman(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Assign New Buyer Picker */}
            <div className="p-3 bg-sky-50 rounded-xl border border-sky-100 flex items-center gap-3">
              <div className="flex-1">
                <select
                  value={assignBuyerId}
                  onChange={(e) => setAssignBuyerId(e.target.value)}
                  className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="">-- Choose Buyer to Assign to this Salesman --</option>
                  {allBuyers
                    .filter((b: any) => b.assignedSalesmanId !== viewingBuyersSalesman.id)
                    .map((b: any) => (
                      <option key={b.id} value={b.id}>
                        {b.businessName || b.user?.fullName} ({b.buyerType}) • Phone: {b.user?.phone}
                      </option>
                    ))}
                </select>
              </div>
              <button
                disabled={!assignBuyerId || assignBuyerMutation.isPending}
                onClick={() =>
                  assignBuyerMutation.mutate({
                    salesmanId: viewingBuyersSalesman.id,
                    buyerProfileId: assignBuyerId,
                  })
                }
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-sm disabled:opacity-50 whitespace-nowrap"
              >
                + Assign Buyer
              </button>
            </div>

            {/* List of currently assigned buyers */}
            <div className="space-y-2 max-h-80 overflow-y-auto">
              {assignedBuyers.length === 0 ? (
                <div className="text-center py-8 text-slate-400 text-xs">
                  No buyers currently assigned to this salesman. Use the dropdown above to assign dealer accounts.
                </div>
              ) : (
                assignedBuyers.map((b: any) => (
                  <div
                    key={b.id}
                    className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-center justify-between text-xs"
                  >
                    <div>
                      <div className="font-bold text-slate-900">{b.businessName || b.user?.fullName}</div>
                      <div className="text-[11px] text-slate-500 mt-0.5 flex items-center gap-2">
                        <span className="px-1.5 py-0.5 bg-sky-100 text-sky-800 rounded font-bold text-[9px]">
                          {b.buyerType}
                        </span>
                        <span>Phone: {b.user?.phone}</span>
                        <span>Orders: {b.totalOrders || 0}</span>
                      </div>
                    </div>

                    <button
                      onClick={() =>
                        unassignBuyerMutation.mutate({
                          salesmanId: viewingBuyersSalesman.id,
                          buyerId: b.id,
                        })
                      }
                      className="px-2.5 py-1 text-rose-600 hover:bg-rose-50 border border-rose-200 rounded-lg font-bold text-[11px] transition-all"
                      title="Unassign Buyer"
                    >
                      Unassign
                    </button>
                  </div>
                ))
              )}
            </div>

            <div className="pt-2 text-right">
              <button
                onClick={() => setViewingBuyersSalesman(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl text-xs"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* SALES HISTORY & ORDERS WITH DATE FILTERS MODAL */}
      {historySalesman && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-black text-slate-900 flex items-center gap-2">
                  <ShoppingBag className="w-5 h-5 text-emerald-600" />
                  Sales History & Order Performance
                </h2>
                <p className="text-xs text-slate-500 font-mono">
                  {historySalesman.employeeCode} • {historySalesman.user?.fullName}
                </p>
              </div>
              <button onClick={() => setHistorySalesman(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Filter Bar: Date Range & Specific Buyer */}
            <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 grid grid-cols-1 sm:grid-cols-4 gap-3 text-xs">
              <div>
                <label className="block font-bold text-slate-600 mb-1">From Date</label>
                <input
                  type="date"
                  value={historyStartDate}
                  onChange={(e) => setHistoryStartDate(e.target.value)}
                  className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500 font-mono"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-600 mb-1">To Date</label>
                <input
                  type="date"
                  value={historyEndDate}
                  onChange={(e) => setHistoryEndDate(e.target.value)}
                  className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500 font-mono"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-600 mb-1">Filter by Buyer</label>
                <select
                  value={historyBuyerId}
                  onChange={(e) => setHistoryBuyerId(e.target.value)}
                  className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="">All Buyers</option>
                  {allBuyers.map((b: any) => (
                    <option key={b.id} value={b.id}>
                      {b.businessName || b.user?.fullName} ({b.buyerType})
                    </option>
                  ))}
                </select>
              </div>

              <div className="flex items-end">
                <button
                  onClick={() => {
                    setHistoryStartDate('');
                    setHistoryEndDate('');
                    setHistoryBuyerId('');
                  }}
                  className="w-full py-2 bg-white hover:bg-slate-100 text-slate-700 border border-slate-200 font-bold rounded-xl transition-all"
                >
                  Reset Filters
                </button>
              </div>
            </div>

            {/* Summary Metrics Strip */}
            <div className="p-4 bg-slate-900 text-white rounded-2xl grid grid-cols-2 sm:grid-cols-4 gap-4 font-mono">
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-sans">Total Sales Done</span>
                <p className="text-xl font-black text-emerald-400 mt-0.5">
                  ₹{Number(historySummary.totalSales || 0).toLocaleString('en-IN')}
                </p>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-sans">Collected Revenue</span>
                <p className="text-xl font-black text-sky-400 mt-0.5">
                  ₹{Number(historySummary.totalPaid || 0).toLocaleString('en-IN')}
                </p>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-sans">Total Orders Count</span>
                <p className="text-xl font-black text-white mt-0.5">
                  {historySummary.totalOrders || 0} ({historySummary.deliveredCount || 0} Delivered)
                </p>
              </div>
              <div>
                <span className="text-[10px] text-slate-400 uppercase font-sans">Provisional 3% Commission</span>
                <p className="text-xl font-black text-amber-400 mt-0.5">
                  ₹{Number(historySummary.provisionalCommission || 0).toLocaleString('en-IN')}
                </p>
              </div>
            </div>

            {/* Orders Table */}
            <div className="border border-slate-200 rounded-xl overflow-hidden max-h-72 overflow-y-auto">
              <table className="w-full text-left text-xs">
                <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold sticky top-0">
                  <tr>
                    <th className="px-4 py-2.5">Order #</th>
                    <th className="px-4 py-2.5">Date</th>
                    <th className="px-4 py-2.5">Buyer</th>
                    <th className="px-4 py-2.5">Items</th>
                    <th className="px-4 py-2.5">Total Amount</th>
                    <th className="px-4 py-2.5">Payment</th>
                    <th className="px-4 py-2.5">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 font-mono">
                  {isHistoryLoading ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-400">Loading orders...</td>
                    </tr>
                  ) : historyOrders.length === 0 ? (
                    <tr>
                      <td colSpan={7} className="text-center py-8 text-slate-400">
                        No orders recorded matching this period or buyer filter.
                      </td>
                    </tr>
                  ) : (
                    historyOrders.map((o: any) => (
                      <tr key={o.id} className="hover:bg-slate-50">
                        <td className="px-4 py-2.5 font-bold text-slate-900">{o.orderNumber}</td>
                        <td className="px-4 py-2.5 text-slate-500 font-sans">
                          {new Date(o.createdAt).toLocaleDateString('en-IN', {
                            day: 'numeric',
                            month: 'short',
                            year: 'numeric',
                          })}
                        </td>
                        <td className="px-4 py-2.5 font-sans font-medium text-slate-800">
                          {o.buyer?.businessName || o.buyer?.user?.fullName || 'Buyer'}
                        </td>
                        <td className="px-4 py-2.5">{o.items?.length || 0}</td>
                        <td className="px-4 py-2.5 font-bold text-slate-900">
                          ₹{Number(o.finalAmount).toLocaleString('en-IN')}
                        </td>
                        <td className="px-4 py-2.5">
                          <span
                            className={`px-1.5 py-0.5 rounded text-[10px] font-bold ${
                              o.paymentStatus === 'PAID'
                                ? 'bg-emerald-100 text-emerald-800'
                                : 'bg-amber-100 text-amber-800'
                            }`}
                          >
                            {o.paymentStatus}
                          </span>
                        </td>
                        <td className="px-4 py-2.5 font-sans">
                          <span className="px-2 py-0.5 bg-slate-100 rounded text-[10px] font-bold text-slate-700">
                            {o.status}
                          </span>
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>

            <div className="pt-2 flex justify-between items-center text-xs text-slate-500">
              <span>Showing {historyOrders.length} orders in filtered date range</span>
              <button
                onClick={() => setHistorySalesman(null)}
                className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* DELETE CONFIRMATION DIALOG */}
      {deleteConfirmId && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-6 shadow-2xl border border-slate-100 space-y-4 text-center">
            <div className="w-12 h-12 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center mx-auto">
              <Trash2 className="w-6 h-6" />
            </div>
            <div>
              <h3 className="font-bold text-slate-900 text-base">Remove Sales Representative?</h3>
              <p className="text-xs text-slate-500 mt-1">
                Are you sure you want to delete this salesman? All assigned buyers will be released back to the corporate account pool.
              </p>
            </div>
            <div className="flex items-center gap-3 pt-2">
              <button
                type="button"
                onClick={() => setDeleteConfirmId(null)}
                className="flex-1 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={deleteSalesmanMutation.isPending}
                onClick={() => deleteSalesmanMutation.mutate(deleteConfirmId)}
                className="flex-1 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {deleteSalesmanMutation.isPending ? 'Deleting...' : 'Confirm Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
