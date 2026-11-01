'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  FileText,
  Plus,
  Search,
  Filter,
  CheckCircle,
  XCircle,
  Clock,
  Download,
  Eye,
  AlertCircle,
  ShoppingCart,
  X,
  FileCheck,
  Edit2,
  Trash2,
  User,
  Briefcase,
  DollarSign,
  Package,
  Layers,
  Sparkles,
  Camera,
} from 'lucide-react';

interface QuotationItemRow {
  productId: string;
  productName: string;
  sku: string;
  quantity: number;
  unitPrice: number;
  taxRate: number;
  lineTotal: number;
}

interface QuotationModalState {
  isOpen: boolean;
  mode: 'create' | 'edit';
  id?: string;
  buyerProfileId: string;
  salesmanProfileId: string; // 'NONE' or salesmanProfileId
  status: string; // 'DRAFT' | 'ISSUED' | 'ACCEPTED'
  validityDays: number;
  paymentTerms: string;
  shippingCharges: number;
  taxRate: number;
  additionalDiscountRequested: number;
  discountReason: string;
  buyerNotes: string;
  internalNotes: string;
  items: QuotationItemRow[];
}

const initialModalState: QuotationModalState = {
  isOpen: false,
  mode: 'create',
  buyerProfileId: '',
  salesmanProfileId: 'NONE',
  status: 'ISSUED',
  validityDays: 15,
  paymentTerms: 'Payment on Delivery / Approved Credit',
  shippingCharges: 0,
  taxRate: 18,
  additionalDiscountRequested: 0,
  discountReason: '',
  buyerNotes: '',
  internalNotes: '',
  items: [],
};

export default function QuotationsPage() {
  const queryClient = useQueryClient();
  const [statusFilter, setStatusFilter] = useState('ALL');
  const [search, setSearch] = useState('');
  const [selectedQuotation, setSelectedQuotation] = useState<any>(null);
  const [approvalModal, setApprovalModal] = useState<any>(null);
  const [approvalAction, setApprovalAction] = useState<'APPROVE' | 'REJECT' | 'REVISE'>('APPROVE');
  const [approvalNotes, setApprovalNotes] = useState('');
  const [revisedDiscount, setRevisedDiscount] = useState(0);
  const [approvalTaxRate, setApprovalTaxRate] = useState<number>(18);
  const [approvalShipping, setApprovalShipping] = useState<number>(0);
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [downloadingPdfId, setDownloadingPdfId] = useState<string | null>(null);
  const [templateModalQuotation, setTemplateModalQuotation] = useState<any | null>(null);

  const handleDownloadPdf = async (q: any, template: string = '1') => {
    if (!q?.id) return;
    try {
      setDownloadingPdfId(q.id);
      const res = await api.get(`/quotations/${q.id}/pdf?template=${template}`, {
        responseType: 'blob',
      });
      const blob = new Blob([res as any], { type: 'application/pdf' });
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `GrandAqua-Quotation-T${template}-${q.quotationNumber || q.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (err: any) {
      window.open(`http://localhost:4000/api/v1/quotations/${q.id}/pdf?template=${template}`, '_blank');
    } finally {
      setDownloadingPdfId(null);
    }
  };

  // Form Modal State (Create / Edit)
  const [formModal, setFormModal] = useState<QuotationModalState>(initialModalState);

  // 1. Fetch Quotations
  const { data: quotationsData, isLoading } = useQuery({
    queryKey: ['quotations-list', statusFilter],
    queryFn: () => {
      let url = '/quotations?limit=50';
      if (statusFilter !== 'ALL') url += `&status=${statusFilter}`;
      return api.get(url);
    },
  });
  const quotations = (quotationsData as any)?.quotations || [];

  // 2. Fetch Buyers for Dropdown
  const { data: buyersData } = useQuery({
    queryKey: ['buyers-dropdown'],
    queryFn: () => api.get('/buyers?limit=100'),
  });
  const buyersList = (buyersData as any)?.buyers || (Array.isArray(buyersData) ? buyersData : []);

  // 3. Fetch Salesmen for Dropdown
  const { data: salesmenData } = useQuery({
    queryKey: ['salesmen-dropdown'],
    queryFn: () => api.get('/salesmen'),
  });
  const salesmenList = Array.isArray(salesmenData)
    ? salesmenData
    : (salesmenData as any)?.data || [];

  // 4. Fetch Products for Line Items
  const { data: productsData } = useQuery({
    queryKey: ['products-dropdown'],
    queryFn: () => api.get('/products?limit=100'),
  });
  const productsList = (productsData as any)?.products || (Array.isArray(productsData) ? productsData : []);

  // Mutations
  const createQuotationMutation = useMutation({
    mutationFn: (payload: any) => api.post('/quotations', payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      setFormModal(initialModalState);
      alert('Quotation created successfully!');
    },
    onError: (err: any) => alert(`Failed to create quotation: ${err.message}`),
  });

  const updateQuotationMutation = useMutation({
    mutationFn: (vars: any) => api.put(`/quotations/${vars.id}`, vars.payload),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      setFormModal(initialModalState);
      alert('Quotation updated successfully!');
    },
    onError: (err: any) => alert(`Failed to update quotation: ${err.message}`),
  });

  const updateStatusMutation = useMutation({
    mutationFn: (vars: { id: string; status: string }) =>
      api.put(`/quotations/${vars.id}/status`, { status: vars.status }),
    onSuccess: (_, vars) => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      if (selectedQuotation && selectedQuotation.id === vars.id) {
        setSelectedQuotation((prev: any) => ({ ...prev, status: vars.status }));
      }
      alert(`Quotation status changed to "${vars.status}" successfully!`);
    },
    onError: (err: any) => alert(`Error changing status: ${err.message}`),
  });

  const deleteQuotationMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/quotations/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      setDeleteConfirmId(null);
      if (selectedQuotation) setSelectedQuotation(null);
      alert('Quotation deleted successfully.');
    },
    onError: (err: any) => alert(`Failed to delete quotation: ${err.message}`),
  });

  const reviewDiscountMutation = useMutation({
    mutationFn: async (vars: any) => {
      await api.put(`/quotations/${vars.id}/review-discount`, {
        action: vars.action,
        notes: vars.notes,
        revisedDiscount: vars.revisedDiscount,
      });
      if (vars.action !== 'REJECT') {
        await api.put(`/quotations/${vars.id}`, {
          taxRate: vars.taxRate,
          shippingCharges: vars.shippingCharges,
        });
      }
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      setApprovalModal(null);
      setApprovalNotes('');
      alert('Quotation review finalized with selected GST slab & shipping charges!');
    },
    onError: (err: any) => alert(`Error: ${err.message}`),
  });

  const convertToOrderMutation = useMutation({
    mutationFn: (id: string) => api.post(`/quotations/${id}/convert-to-order`, {}),
    onSuccess: (order: any) => {
      queryClient.invalidateQueries({ queryKey: ['quotations-list'] });
      if (selectedQuotation) {
        setSelectedQuotation((prev: any) => ({ ...prev, status: 'CONVERTED_TO_ORDER' }));
      }
      alert(`Successfully converted Quotation to Order ${order.orderNumber || ''}!`);
    },
    onError: (err: any) => alert(`Error converting to order: ${err.message}`),
  });

  // Calculate Unit Price based on Buyer Type
  const getProductPriceForBuyer = (product: any, buyerType: string) => {
    if (!product || !product.pricing) return 0;
    const p = product.pricing;
    if (buyerType === 'DISTRIBUTOR') return Number(p.distributorPrice || 0);
    if (buyerType === 'WHOLESALER') return Number(p.wholesalerPrice || 0);
    if (buyerType === 'DEALER') return Number(p.dealerPrice || 0);
    return Number(p.customerPrice || 0);
  };

  const openCreateModal = () => {
    const defaultBuyer = buyersList.length > 0 ? buyersList[0] : null;
    let initialItems: QuotationItemRow[] = [];
    if (productsList.length > 0 && defaultBuyer) {
      const p = productsList[0];
      const unitPrice = getProductPriceForBuyer(p, defaultBuyer.buyerType);
      initialItems.push({
        productId: p.id,
        productName: p.name,
        sku: p.sku,
        quantity: 1,
        unitPrice,
        taxRate: 18.0,
        lineTotal: unitPrice * 1.18,
      });
    }

    setFormModal({
      ...initialModalState,
      isOpen: true,
      mode: 'create',
      buyerProfileId: defaultBuyer ? defaultBuyer.id : '',
      salesmanProfileId: 'NONE', // Default to None option!
      status: 'ISSUED',
      taxRate: 18,
      items: initialItems,
    });
  };

  const openEditModal = (quo: any) => {
    const items: QuotationItemRow[] = (quo.items || []).map((i: any) => ({
      productId: i.productId,
      productName: i.productName || i.product?.name || 'Product',
      sku: i.sku || i.product?.sku || '',
      quantity: Number(i.quantity) || 1,
      unitPrice: Number(i.unitPrice) || 0,
      taxRate: Number(i.taxRate) || 18.0,
      lineTotal: Number(i.totalPrice) || 0,
    }));

    setFormModal({
      isOpen: true,
      mode: 'edit',
      id: quo.id,
      buyerProfileId: quo.buyerProfileId || quo.buyer?.id || '',
      salesmanProfileId: quo.salesmanProfileId || 'NONE',
      status: quo.status || 'ISSUED',
      validityDays: 15,
      paymentTerms: quo.paymentTerms || 'Payment on Delivery / Approved Credit',
      shippingCharges: Number(quo.shippingCharges) || 0,
      taxRate: quo.taxRate !== undefined && quo.taxRate !== null && Number(quo.taxRate) > 0 ? Number(quo.taxRate) : 18,
      additionalDiscountRequested: Number(quo.additionalDiscountRequested) || 0,
      discountReason: quo.discountReason || '',
      buyerNotes: quo.buyerNotes || '',
      internalNotes: quo.internalNotes || '',
      items: items.length > 0 ? items : [],
    });
  };

  // Add Item in Modal Form
  const handleAddItem = () => {
    if (productsList.length === 0) return;
    const selectedBuyer = buyersList.find((b: any) => b.id === formModal.buyerProfileId);
    const buyerType = selectedBuyer ? selectedBuyer.buyerType : 'CUSTOMER';
    const p = productsList[0];
    const unitPrice = getProductPriceForBuyer(p, buyerType);
    const lineTotal = unitPrice * 1.18;

    setFormModal((prev) => ({
      ...prev,
      items: [
        ...prev.items,
        {
          productId: p.id,
          productName: p.name,
          sku: p.sku,
          quantity: 1,
          unitPrice,
          taxRate: 18.0,
          lineTotal,
        },
      ],
    }));
  };

  // Update line item in Modal Form
  const handleUpdateItem = (index: number, field: string, value: any) => {
    const selectedBuyer = buyersList.find((b: any) => b.id === formModal.buyerProfileId);
    const buyerType = selectedBuyer ? selectedBuyer.buyerType : 'CUSTOMER';

    const updated = [...formModal.items];
    const current = { ...updated[index] };

    if (field === 'productId') {
      const prod = productsList.find((p: any) => p.id === value);
      if (prod) {
        current.productId = prod.id;
        current.productName = prod.name;
        current.sku = prod.sku;
        current.unitPrice = getProductPriceForBuyer(prod, buyerType);
      }
    } else if (field === 'quantity') {
      current.quantity = Math.max(1, Number(value) || 1);
    } else if (field === 'unitPrice') {
      current.unitPrice = Math.max(0, Number(value) || 0);
    }

    const sub = current.unitPrice * current.quantity;
    const tax = (sub * current.taxRate) / 100;
    current.lineTotal = sub + tax;

    updated[index] = current;
    setFormModal((prev) => ({ ...prev, items: updated }));
  };

  const handleRemoveItem = (index: number) => {
    if (formModal.items.length <= 1) {
      alert('Quotation must contain at least 1 product item.');
      return;
    }
    setFormModal((prev) => ({
      ...prev,
      items: prev.items.filter((_, idx) => idx !== index),
    }));
  };

  // Compute live totals for Modal Form
  const formSubtotal = formModal.items.reduce(
    (acc, it) => acc + (it.unitPrice * it.quantity),
    0,
  );
  const formTaxRate = formModal.taxRate !== undefined ? Number(formModal.taxRate) : 18;
  const formTaxAmount = (formSubtotal * formTaxRate) / 100;
  const formDiscount = Number(formModal.additionalDiscountRequested) || 0;
  const formShipping = Number(formModal.shippingCharges) || 0;
  const formFinalTotal = Math.max(0, formSubtotal + formTaxAmount + formShipping - formDiscount);

  const handleFormSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!formModal.buyerProfileId) {
      alert('Please select a Buyer.');
      return;
    }
    if (formModal.items.length === 0) {
      alert('Please add at least one line item.');
      return;
    }

    const payload: any = {
      buyerProfileId: formModal.buyerProfileId,
      salesmanProfileId: formModal.salesmanProfileId === 'NONE' ? null : formModal.salesmanProfileId,
      status: formModal.status,
      validityDays: Number(formModal.validityDays) || 15,
      paymentTerms: formModal.paymentTerms,
      shippingCharges: Number(formModal.shippingCharges) || 0,
      taxRate: formTaxRate,
      additionalDiscountRequested: Number(formModal.additionalDiscountRequested) || 0,
      discountReason: formModal.discountReason,
      buyerNotes: formModal.buyerNotes,
      internalNotes: formModal.internalNotes,
      items: formModal.items.map((i) => ({
        productId: i.productId,
        quantity: i.quantity,
        unitPrice: i.unitPrice,
      })),
    };

    if (formModal.mode === 'create') {
      createQuotationMutation.mutate(payload);
    } else if (formModal.id) {
      updateQuotationMutation.mutate({ id: formModal.id, payload });
    }
  };

  const getStatusBadge = (status: string) => {
    if (status === 'PENDING_DISCOUNT_APPROVAL') {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-100 text-amber-800 animate-pulse">
          <Clock className="w-3 h-3" /> Pending Approval
        </span>
      );
    }
    if (status === 'CONVERTED_TO_ORDER') {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-100 text-emerald-800">
          <ShoppingCart className="w-3 h-3" /> Converted to Order
        </span>
      );
    }
    if (status === 'ACCEPTED') {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-teal-100 text-teal-800 shadow-sm border border-teal-200">
          <CheckCircle className="w-3 h-3" /> Accepted
        </span>
      );
    }
    if (status === 'REJECTED' || status === 'DISCOUNT_REJECTED') {
      return (
        <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-red-100 text-red-800">
          <XCircle className="w-3 h-3" /> {status.replace('_', ' ')}
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[11px] font-bold bg-sky-100 text-sky-800">
        <FileText className="w-3 h-3" /> {status}
      </span>
    );
  };

  const filteredQuotations = quotations.filter((q: any) => {
    if (!search.trim()) return true;
    const term = search.toLowerCase();
    const qNum = (q.quotationNumber || '').toLowerCase();
    const bName = (q.buyer?.businessName || q.buyer?.user?.fullName || '').toLowerCase();
    const sName = (q.salesman?.user?.fullName || '').toLowerCase();
    return qNum.includes(term) || bName.includes(term) || sName.includes(term);
  });

  return (
    <div className="space-y-6">
      {/* Top Banner & Main Actions */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <FileText className="w-6 h-6 text-sky-600" />
            Quotations & Commercial Management
          </h1>
          <p className="text-sm text-slate-500">
            Create, edit, approve, set status to Accepted, assign sales staff (or None), and convert directly to Orders.
          </p>
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <button
            onClick={openCreateModal}
            className="flex-1 sm:flex-none px-4 py-2.5 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md flex items-center justify-center gap-1.5 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Create New Quotation</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Toolbar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search quotation #, buyer, or staff..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
          />
        </div>

        {/* Status Filters */}
        <div className="flex flex-wrap gap-1.5 p-1 bg-slate-50 border border-slate-200 rounded-xl text-xs w-full md:w-auto overflow-x-auto">
          {['ALL', 'PENDING_DISCOUNT_APPROVAL', 'ISSUED', 'ACCEPTED', 'CONVERTED_TO_ORDER', 'REJECTED'].map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3 py-1.5 font-bold rounded-lg transition-all whitespace-nowrap ${
                statusFilter === st ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {st === 'ALL'
                ? 'All Statuses'
                : st === 'PENDING_DISCOUNT_APPROVAL'
                ? 'Pending Approval'
                : st.replace(/_/g, ' ')}
            </button>
          ))}
        </div>
      </div>

      {/* Quotations Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Quotation #</th>
                <th className="px-5 py-3.5">Buyer & Tier</th>
                <th className="px-5 py-3.5">Sales Staff</th>
                <th className="px-5 py-3.5">Grand Total</th>
                <th className="px-5 py-3.5">Special Discount</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">Loading quotations...</td>
                </tr>
              ) : filteredQuotations.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">
                    No quotations found matching your criteria.
                  </td>
                </tr>
              ) : (
                filteredQuotations.map((quo: any) => (
                  <tr key={quo.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-4 font-mono font-bold text-slate-900">
                      <div>{quo.quotationNumber}</div>
                      <span className="text-[10px] text-slate-400 font-sans font-normal">
                        {new Date(quo.createdAt).toLocaleDateString('en-IN', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </span>
                    </td>

                    <td className="px-5 py-4">
                      <div className="font-bold text-slate-800">
                        {quo.buyer?.businessName || quo.buyer?.user?.fullName || 'Individual Buyer'}
                      </div>
                      <span className="inline-block mt-0.5 px-2 py-0.5 rounded text-[10px] font-bold bg-sky-50 text-sky-700 border border-sky-100">
                        {quo.buyer?.buyerType || 'CUSTOMER'}
                      </span>
                    </td>

                    <td className="px-5 py-4">
                      {quo.salesman?.user?.fullName ? (
                        <div className="flex items-center gap-1.5 text-slate-700 font-medium">
                          <User className="w-3.5 h-3.5 text-slate-400" />
                          <span>{quo.salesman.user.fullName}</span>
                        </div>
                      ) : (
                        <span className="inline-block px-2 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-600 border border-slate-200">
                          Direct / None
                        </span>
                      )}
                    </td>

                    <td className="px-5 py-4 font-mono font-bold text-slate-900">
                      ₹{Number(quo.finalTotal || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 })}
                      <div className="text-[10px] font-sans font-normal text-slate-400">
                        {quo.items?.length || 0} items • GST ({quo.taxRate !== undefined && quo.taxRate !== null && Number(quo.taxRate) > 0 ? `${quo.taxRate}%` : 'Pending'})
                      </div>
                      <div className="mt-1 inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-50 text-emerald-800 border border-emerald-200">
                        <span>Profit: ₹{Number(quo.profit || 0).toLocaleString('en-IN')}</span>
                        {quo.profitMargin !== undefined && (
                          <span className="text-emerald-600 font-medium">({quo.profitMargin}%)</span>
                        )}
                      </div>
                    </td>

                    <td className="px-5 py-4">
                      {Number(quo.additionalDiscountRequested || 0) > 0 ? (
                        <div className="font-mono text-amber-700 font-bold">
                          ₹{Number(quo.additionalDiscountRequested).toLocaleString('en-IN')}
                          <div className="text-[10px] font-sans font-normal text-slate-400">
                            Status: {quo.discountApprovalStatus}
                          </div>
                        </div>
                      ) : (
                        <span className="text-slate-400 font-mono">₹0</span>
                      )}
                    </td>

                    <td className="px-5 py-4">
                      {getStatusBadge(quo.status)}
                    </td>

                    <td className="px-5 py-4 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        {/* 1-Click Set Accepted Button */}
                        {quo.status !== 'ACCEPTED' && quo.status !== 'CONVERTED_TO_ORDER' && (
                          <button
                            onClick={() => updateStatusMutation.mutate({ id: quo.id, status: 'ACCEPTED' })}
                            title="Set Quotation Status to Accepted"
                            className="px-2.5 py-1.5 bg-teal-50 hover:bg-teal-100 text-teal-700 border border-teal-200 font-bold rounded-lg text-xs flex items-center gap-1 transition-all"
                          >
                            <CheckCircle className="w-3.5 h-3.5 text-teal-600" />
                            <span>Accept</span>
                          </button>
                        )}

                        {/* Convert to Order Button */}
                        {quo.status === 'ACCEPTED' && (
                          <button
                            onClick={() => convertToOrderMutation.mutate(quo.id)}
                            disabled={convertToOrderMutation.isPending}
                            title="Convert into Confirmed Order"
                            className="px-2.5 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-lg text-xs flex items-center gap-1 shadow-sm transition-all"
                          >
                            <ShoppingCart className="w-3.5 h-3.5" />
                            <span>To Order</span>
                          </button>
                        )}

                        {/* Discount Review Action */}
                        {quo.status === 'PENDING_DISCOUNT_APPROVAL' && (
                          <button
                            onClick={() => {
                              setApprovalModal(quo);
                              setRevisedDiscount(Number(quo.additionalDiscountRequested || 0));
                              setApprovalTaxRate(quo.taxRate && Number(quo.taxRate) > 0 ? Number(quo.taxRate) : 18);
                              setApprovalShipping(Number(quo.shippingCharges || 0));
                            }}
                            className="px-2.5 py-1.5 bg-amber-500 hover:bg-amber-600 text-white font-bold rounded-lg text-xs flex items-center gap-1 shadow-sm transition-all"
                          >
                            <FileCheck className="w-3.5 h-3.5" />
                            <span>Review</span>
                          </button>
                        )}

                        {/* View Details */}
                        <button
                          onClick={() => setSelectedQuotation(quo)}
                          className="p-1.5 text-slate-600 hover:text-sky-600 hover:bg-sky-50 rounded-lg border border-slate-200 transition-all"
                          title="View Itemized Quotation"
                        >
                          <Eye className="w-4 h-4" />
                        </button>

                        {/* Download PDF (3 Templates) */}
                        <button
                          onClick={() => setTemplateModalQuotation(quo)}
                          disabled={downloadingPdfId === quo.id}
                          className="p-1.5 text-slate-600 hover:text-sky-600 hover:bg-sky-50 rounded-lg border border-slate-200 transition-all"
                          title="Download Quotation PDF (Choose from 3 Templates)"
                        >
                          <Download className={`w-4 h-4 ${downloadingPdfId === quo.id ? 'animate-bounce text-sky-600' : ''}`} />
                        </button>

                        {/* Edit Quotation */}
                        <button
                          onClick={() => openEditModal(quo)}
                          className="p-1.5 text-slate-600 hover:text-sky-600 hover:bg-sky-50 rounded-lg border border-slate-200 transition-all"
                          title="Edit Quotation"
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>

                        {/* Delete Quotation */}
                        {quo.status !== 'CONVERTED_TO_ORDER' && (
                          <button
                            onClick={() => setDeleteConfirmId(quo.id)}
                            className="p-1.5 text-rose-500 hover:text-rose-700 hover:bg-rose-50 rounded-lg border border-slate-200 transition-all"
                            title="Delete Quotation"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* CREATE / EDIT QUOTATION MODAL */}
      {formModal.isOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-lg font-black text-slate-900 flex items-center gap-2">
                  <FileText className="w-5 h-5 text-sky-600" />
                  {formModal.mode === 'create' ? 'Create New Quotation' : 'Edit Quotation'}
                </h2>
                <p className="text-xs text-slate-500">
                  Select buyer, assign sales staff (or None), configure line items, set status to Accepted or Issued, and calculate live totals.
                </p>
              </div>
              <button
                onClick={() => setFormModal(initialModalState)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleFormSubmit} className="space-y-4 text-xs">
              {/* Buyer, Sales Staff & Status Row */}
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 p-4 bg-slate-50 rounded-2xl border border-slate-200">
                {/* Buyer selection */}
                <div>
                  <label className="block font-bold text-slate-700 mb-1">Select Buyer *</label>
                  <select
                    required
                    value={formModal.buyerProfileId}
                    onChange={(e) => {
                      const newBuyerId = e.target.value;
                      const selectedB = buyersList.find((b: any) => b.id === newBuyerId);
                      const bType = selectedB ? selectedB.buyerType : 'CUSTOMER';
                      // Recompute item unit prices based on new buyer's tier!
                      const updatedItems = formModal.items.map((it) => {
                        const prod = productsList.find((p: any) => p.id === it.productId);
                        const unitPrice = prod ? getProductPriceForBuyer(prod, bType) : it.unitPrice;
                        const sub = unitPrice * it.quantity;
                        const tax = (sub * it.taxRate) / 100;
                        return {
                          ...it,
                          unitPrice,
                          lineTotal: sub + tax,
                        };
                      });
                      setFormModal((prev) => ({
                        ...prev,
                        buyerProfileId: newBuyerId,
                        items: updatedItems,
                      }));
                    }}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
                  >
                    <option value="">-- Choose Buyer --</option>
                    {buyersList.map((b: any) => (
                      <option key={b.id} value={b.id}>
                        {b.businessName || b.user?.fullName} ({b.buyerType})
                      </option>
                    ))}
                  </select>
                </div>

                {/* Sales Staff selection with explicit None option */}
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Sales Staff / Representative
                  </label>
                  <select
                    value={formModal.salesmanProfileId}
                    onChange={(e) => setFormModal({ ...formModal, salesmanProfileId: e.target.value })}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
                  >
                    <option value="NONE">None (Direct Company — No Sales Staff)</option>
                    {salesmenList.map((s: any) => (
                      <option key={s.id} value={s.id}>
                        {s.user?.fullName} ({s.employeeCode || 'Sales Staff'})
                      </option>
                    ))}
                  </select>
                  <span className="text-[10px] text-slate-400 block mt-0.5">
                    Select "None" for direct corporate orders without commission.
                  </span>
                </div>

                {/* Quotation Status Selector (Explicitly can set to Accepted!) */}
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Initial / Target Status
                  </label>
                  <select
                    value={formModal.status}
                    onChange={(e) => setFormModal({ ...formModal, status: e.target.value })}
                    className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-bold focus:outline-none focus:ring-2 focus:ring-sky-500 text-sky-800"
                  >
                    <option value="ISSUED">ISSUED (Ready for Buyer)</option>
                    <option value="PENDING_DISCOUNT_APPROVAL">PENDING APPROVAL (Awaiting Review)</option>
                    <option value="ACCEPTED">ACCEPTED (Pre-approved / Ready for Order)</option>
                    <option value="DRAFT">DRAFT (Internal Preparation)</option>
                  </select>
                  <span className="text-[10px] text-teal-600 block mt-0.5 font-medium">
                    Super Admin can directly set status to ACCEPTED.
                  </span>
                </div>
              </div>

              {/* Dynamic Line Items Section */}
              <div className="space-y-3 p-4 bg-sky-50/50 rounded-2xl border border-sky-100">
                <div className="flex items-center justify-between">
                  <span className="font-bold text-slate-800 flex items-center gap-1.5">
                    <Package className="w-4 h-4 text-sky-600" />
                    Quotation Line Items & 4-Tier Snapshot Pricing
                  </span>
                  <button
                    type="button"
                    onClick={handleAddItem}
                    className="px-3 py-1 bg-white hover:bg-sky-50 text-sky-700 border border-sky-200 font-bold rounded-lg text-xs flex items-center gap-1 shadow-sm transition-all"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>Add Item</span>
                  </button>
                </div>

                <div className="space-y-2">
                  {formModal.items.map((it, idx) => (
                    <div
                      key={idx}
                      className="grid grid-cols-12 gap-2 bg-white p-3 rounded-xl border border-slate-200 items-center"
                    >
                      {/* Product Dropdown & Thumbnail */}
                      <div className="col-span-12 sm:col-span-5 flex items-center gap-2">
                        {(() => {
                          const prod = productsList.find((p: any) => p.id === it.productId);
                          const imgObj = prod?.media?.find((m: any) => m.mediaType === 'IMAGE') || prod?.media?.[0];
                          let imgUrl = imgObj?.url || prod?.imageUrl;
                          if (imgUrl && imgUrl.startsWith('/uploads/')) imgUrl = `http://localhost:4000${imgUrl}`;
                          return imgUrl ? (
                            <img
                              src={imgUrl}
                              alt={prod?.name || 'Product'}
                              className="w-8 h-8 rounded border border-slate-200 object-contain bg-white shrink-0 mt-3 shadow-xs"
                              onError={(e) => {
                                (e.target as HTMLElement).style.display = 'none';
                              }}
                            />
                          ) : (
                            <div className="w-8 h-8 rounded-full border border-slate-200 bg-slate-50 flex items-center justify-center shrink-0 mt-3 text-slate-400">
                              <Camera className="w-3.5 h-3.5 text-slate-400" />
                            </div>
                          );
                        })()}
                        <div className="flex-1 min-w-0">
                          <label className="block text-[10px] text-slate-400 font-semibold mb-0.5">Product</label>
                          <select
                            value={it.productId}
                            onChange={(e) => handleUpdateItem(idx, 'productId', e.target.value)}
                            className="w-full px-2 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-medium focus:outline-none focus:ring-2 focus:ring-sky-500"
                          >
                            {productsList.map((p: any) => (
                              <option key={p.id} value={p.id}>
                                {p.sku} • {p.name}
                              </option>
                            ))}
                          </select>
                        </div>
                      </div>

                      {/* Quantity */}
                      <div className="col-span-4 sm:col-span-2">
                        <label className="block text-[10px] text-slate-400 font-semibold mb-0.5">Quantity</label>
                        <input
                          type="number"
                          min="1"
                          value={it.quantity}
                          onChange={(e) => handleUpdateItem(idx, 'quantity', e.target.value)}
                          className="w-full px-2 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                        />
                      </div>

                      {/* Unit Price */}
                      <div className="col-span-4 sm:col-span-2">
                        <label className="block text-[10px] text-slate-400 font-semibold mb-0.5">Unit Price (₹)</label>
                        <input
                          type="number"
                          min="0"
                          value={it.unitPrice}
                          onChange={(e) => handleUpdateItem(idx, 'unitPrice', e.target.value)}
                          className="w-full px-2 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono font-bold text-sky-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                        />
                      </div>

                      {/* Total Incl. 18% GST */}
                      <div className="col-span-3 sm:col-span-2 font-mono font-bold text-slate-900 text-right">
                        <label className="block text-[10px] text-slate-400 font-semibold mb-0.5">Total (18% GST)</label>
                        <div className="pt-1.5">₹{it.lineTotal.toLocaleString('en-IN', { maximumFractionDigits: 1 })}</div>
                      </div>

                      {/* Delete item button */}
                      <div className="col-span-1 text-right pt-4 sm:pt-3">
                        <button
                          type="button"
                          onClick={() => handleRemoveItem(idx)}
                          className="text-rose-500 hover:text-rose-700 p-1 hover:bg-rose-50 rounded"
                          title="Remove item"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              {/* Commercial Terms & Notes */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Applicable GST Slab (%)
                  </label>
                  <select
                    value={formModal.taxRate}
                    onChange={(e) =>
                      setFormModal({ ...formModal, taxRate: Number(e.target.value) })
                    }
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono font-bold text-slate-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value={18}>18% (Standard Rate - Plants & Machinery)</option>
                    <option value={12}>12% (Water Purifiers & Domestic RO)</option>
                    <option value={5}>5% (Concessional / Spares & Filters)</option>
                    <option value={0}>0% (Exempted / Zero Tax)</option>
                  </select>
                  <span className="text-[10px] text-slate-500 mt-0.5 block">
                    Choose GST tax slab applicable to this quotation
                  </span>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Shipping Charges (₹)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formModal.shippingCharges}
                    onChange={(e) =>
                      setFormModal({ ...formModal, shippingCharges: Number(e.target.value) })
                    }
                    placeholder="0"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono font-bold text-sky-700 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                  <span className="text-[10px] text-slate-500 mt-0.5 block">
                    Calculated based on products, quantity & km distance
                  </span>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">
                    Special Commercial Discount (₹)
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={formModal.additionalDiscountRequested}
                    onChange={(e) =>
                      setFormModal({ ...formModal, additionalDiscountRequested: Number(e.target.value) })
                    }
                    placeholder="0"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono font-bold text-amber-700 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Discount Rationale / Notes</label>
                  <input
                    type="text"
                    value={formModal.discountReason}
                    onChange={(e) => setFormModal({ ...formModal, discountReason: e.target.value })}
                    placeholder="e.g. Bulk project pricing concession approved by Super Admin"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Payment Terms</label>
                  <input
                    type="text"
                    value={formModal.paymentTerms}
                    onChange={(e) => setFormModal({ ...formModal, paymentTerms: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block font-bold text-slate-700 mb-1">Validity (Days)</label>
                  <input
                    type="number"
                    min="1"
                    max="90"
                    value={formModal.validityDays}
                    onChange={(e) => setFormModal({ ...formModal, validityDays: Number(e.target.value) })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block font-bold text-slate-700 mb-1">Buyer Visible Notes</label>
                  <textarea
                    rows={2}
                    value={formModal.buyerNotes}
                    onChange={(e) => setFormModal({ ...formModal, buyerNotes: e.target.value })}
                    placeholder="Delivery within 48 hours of confirmation. Free installation included..."
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {/* Financial Summary Strip */}
              <div className="p-4 bg-slate-900 text-white rounded-2xl flex flex-col sm:flex-row items-center justify-between gap-4 font-mono">
                <div className="space-y-1 text-xs">
                  <div className="text-slate-400">Subtotal (Excl. Tax): ₹{formSubtotal.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
                  <div className="text-slate-400">GST ({formTaxRate}%): ₹{formTaxAmount.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
                  <div className="text-sky-300">Shipping Charges: +₹{formShipping.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
                  {formDiscount > 0 && (
                    <div className="text-amber-400">Special Discount: -₹{formDiscount.toLocaleString('en-IN', { maximumFractionDigits: 2 })}</div>
                  )}
                </div>

                <div className="text-right">
                  <div className="text-[10px] uppercase tracking-wider text-slate-400">Grand Total Payable</div>
                  <div className="text-2xl font-black text-emerald-400">
                    ₹{formFinalTotal.toLocaleString('en-IN', { maximumFractionDigits: 2 })}
                  </div>
                </div>
              </div>

              {/* Action Buttons */}
              <div className="flex items-center justify-end gap-3 pt-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setFormModal(initialModalState)}
                  className="px-4 py-2 font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createQuotationMutation.isPending || updateQuotationMutation.isPending}
                  className="px-5 py-2.5 bg-sky-600 hover:bg-sky-700 text-white font-bold rounded-xl shadow-md disabled:opacity-50 transition-all flex items-center gap-1.5"
                >
                  <CheckCircle className="w-4 h-4" />
                  <span>
                    {createQuotationMutation.isPending || updateQuotationMutation.isPending
                      ? 'Saving...'
                      : formModal.mode === 'create'
                      ? 'Create Quotation'
                      : 'Update Quotation'}
                  </span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* QUOTATION DETAILS & INVOICE PREVIEW MODAL */}
      {selectedQuotation && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-3xl w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-4">
              <div>
                <span className="text-[10px] font-bold uppercase tracking-widest text-sky-600">
                  Commercial Quotation Summary
                </span>
                <h2 className="text-xl font-black text-slate-900 font-mono flex items-center gap-2">
                  {selectedQuotation.quotationNumber}
                  {getStatusBadge(selectedQuotation.status)}
                </h2>
              </div>
              <button
                onClick={() => setSelectedQuotation(null)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Buyer and Salesman Header */}
            <div className="grid grid-cols-2 gap-4 p-4 bg-slate-50 rounded-2xl text-xs">
              <div>
                <span className="text-slate-400 font-bold block mb-1">PROSPECTIVE BUYER</span>
                <div className="font-bold text-slate-900 text-sm">
                  {selectedQuotation.buyer?.businessName || selectedQuotation.buyer?.user?.fullName}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Type: <strong>{selectedQuotation.buyer?.buyerType}</strong> • Contact: {selectedQuotation.buyer?.user?.phone || 'N/A'}
                </div>
              </div>

              <div>
                <span className="text-slate-400 font-bold block mb-1">SALES STAFF ASSIGNMENT</span>
                {selectedQuotation.salesman?.user?.fullName ? (
                  <>
                    <div className="font-bold text-slate-900 text-sm">
                      {selectedQuotation.salesman.user.fullName}
                    </div>
                    <div className="text-slate-500 mt-0.5">
                      Code: {selectedQuotation.salesman.employeeCode || 'N/A'}
                    </div>
                  </>
                ) : (
                  <div className="font-bold text-slate-700 text-sm">
                    Direct Company Account (No Sales Staff Assigned)
                  </div>
                )}
              </div>
            </div>

            {/* Line Items Table */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-bold text-xs uppercase tracking-wider text-slate-500">Itemized Breakdown</h3>
                <span className="text-[11px] text-slate-400 font-medium">
                  {selectedQuotation.items?.length || 0} Products Quoted
                </span>
              </div>
              <div className="border border-slate-200 rounded-xl overflow-hidden shadow-sm bg-white">
                <table className="w-full text-left text-xs border-collapse">
                  <thead className="bg-slate-50/90 border-b border-slate-200 text-slate-800 font-bold">
                    <tr>
                      <th className="w-10 px-3 py-2.5 text-center border-r border-slate-200">#</th>
                      <th className="w-16 px-3 py-2.5 text-center border-r border-slate-200">Image</th>
                      <th className="px-4 py-2.5 border-r border-slate-200">Product</th>
                      <th className="w-24 px-3 py-2.5 text-center border-r border-slate-200">Qty</th>
                      <th className="w-28 px-3 py-2.5 text-right border-r border-slate-200">Price</th>
                      <th className="w-32 px-3 py-2.5 text-right">Total</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-200 font-mono">
                    {(selectedQuotation.items || []).map((it: any, idx: number) => {
                      const imgObj =
                        it.product?.media?.find((m: any) => m.mediaType === 'IMAGE') ||
                        it.product?.media?.[0];
                      let imgUrl = imgObj?.url || it.product?.imageUrl || it.imageUrl;
                      if (imgUrl && imgUrl.startsWith('/uploads/')) {
                        imgUrl = `http://localhost:4000${imgUrl}`;
                      }

                      return (
                        <tr key={it.id || idx} className="hover:bg-slate-50/50 transition-colors">
                          <td className="px-3 py-3 text-center border-r border-slate-200 text-slate-600 font-bold font-sans">
                            {idx + 1}
                          </td>
                          <td className="px-3 py-3 border-r border-slate-200 text-center">
                            {imgUrl ? (
                              <img
                                src={imgUrl}
                                alt={it.productName || it.product?.name}
                                className="w-10 h-10 object-contain mx-auto rounded border border-slate-200 bg-white p-0.5 shadow-sm"
                                onError={(e) => {
                                  (e.target as HTMLElement).style.display = 'none';
                                  const parent = (e.target as HTMLElement).parentElement;
                                  if (parent) {
                                    const fallback = parent.querySelector('.camera-fallback');
                                    if (fallback) fallback.classList.remove('hidden');
                                  }
                                }}
                              />
                            ) : null}
                            <div
                              className={`camera-fallback w-9 h-9 rounded-full border border-slate-300 flex items-center justify-center mx-auto text-slate-400 bg-slate-50 relative ${
                                imgUrl ? 'hidden' : ''
                              }`}
                              title="No product image"
                            >
                              <Camera className="w-4 h-4 text-slate-400" />
                              <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                <div className="w-5 h-[1.5px] bg-slate-300 rotate-45 transform origin-center"></div>
                              </div>
                            </div>
                          </td>
                          <td className="px-4 py-3 font-sans border-r border-slate-200">
                            <div className="font-bold text-slate-900 text-xs">
                              {it.productName || it.product?.name}
                              {it.sku || it.product?.sku ? (
                                <span className="ml-1 text-slate-600 font-normal">
                                  ({it.sku || it.product?.sku})
                                </span>
                              ) : null}
                            </div>
                            <div className="text-[11px] text-slate-500 font-medium uppercase mt-0.5 tracking-tight">
                              {it.product?.category?.name ||
                                it.product?.shortDescription ||
                                'Grand Aqua Genuine Standard'}
                            </div>
                          </td>
                          <td className="px-3 py-3 text-center border-r border-slate-200">
                            <div className="font-bold text-slate-900">{Number(it.quantity).toFixed(2)}</div>
                            <div className="text-[10px] text-slate-400 font-sans uppercase">
                              {it.product?.unitOfMeasurement || 'PCS'}
                            </div>
                          </td>
                          <td className="px-3 py-3 text-right border-r border-slate-200 text-slate-800">
                            ₹{' '}
                            {Number(it.unitPrice).toLocaleString('en-IN', {
                              minimumFractionDigits: 2,
                              maximumFractionDigits: 2,
                            })}
                          </td>
                          <td className="px-3 py-3 text-right font-bold text-slate-900">
                            ₹{' '}
                            {Number(it.quantity * it.unitPrice).toLocaleString('en-IN', {
                              minimumFractionDigits: 2,
                              maximumFractionDigits: 2,
                            })}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                  <tfoot className="border-t border-slate-200 bg-slate-50 font-mono font-bold">
                    <tr>
                      <td
                        colSpan={5}
                        className="px-4 py-2.5 text-right font-sans text-xs text-slate-700 border-r border-slate-200"
                      >
                        Total
                      </td>
                      <td className="px-3 py-2.5 text-right text-xs text-slate-900 font-mono font-black">
                        ₹{' '}
                        {Number(selectedQuotation.subtotal).toLocaleString('en-IN', {
                          minimumFractionDigits: 2,
                          maximumFractionDigits: 2,
                        })}
                      </td>
                    </tr>
                  </tfoot>
                </table>
              </div>
            </div>

            {/* Financial Totals */}
            <div className="p-4 bg-slate-900 text-white rounded-2xl flex justify-between items-center font-mono">
              <div className="text-xs space-y-1">
                <div>Subtotal: ₹{Number(selectedQuotation.subtotal).toLocaleString('en-IN')}</div>
                <div>GST (18%): ₹{Number(selectedQuotation.taxAmount).toLocaleString('en-IN')}</div>
                <div className="text-sky-300">
                  Shipping: {Number(selectedQuotation.shippingCharges || 0) > 0 
                    ? `₹${Number(selectedQuotation.shippingCharges).toLocaleString('en-IN')}` 
                    : selectedQuotation.status === 'PENDING_DISCOUNT_APPROVAL'
                      ? '⚠️ To be calculated (Based on weight, volume & km)'
                      : '₹0 (Free / Included)'}
                </div>
                {Number(selectedQuotation.additionalDiscountRequested) > 0 && (
                  <div className="text-amber-400">
                    Discount Approved: -₹{Number(selectedQuotation.additionalDiscountApproved || 0).toLocaleString('en-IN')}
                  </div>
                )}
              </div>
              <div className="text-right">
                <div className="text-[10px] text-slate-400 uppercase tracking-widest">Final Grand Total</div>
                <div className="text-2xl font-black text-emerald-400">
                  ₹{Number(selectedQuotation.finalTotal).toLocaleString('en-IN')}
                </div>
              </div>
            </div>

            {/* Actions Toolbar in Details Modal */}
            <div className="flex flex-wrap items-center justify-between gap-3 pt-2 border-t border-slate-100">
              <div className="flex items-center gap-2">
                {/* Edit & Set Shipping / Approve Button */}
                <button
                  onClick={() => {
                    const quo = selectedQuotation;
                    setSelectedQuotation(null);
                    openEditModal(quo);
                  }}
                  className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm transition-all"
                >
                  <Edit2 className="w-4 h-4" />
                  <span>Edit & Set Shipping / Approve</span>
                </button>

                {/* 1-Click Set Accepted */}
                {selectedQuotation.status !== 'ACCEPTED' && selectedQuotation.status !== 'CONVERTED_TO_ORDER' && (
                  <button
                    onClick={() => updateStatusMutation.mutate({ id: selectedQuotation.id, status: 'ACCEPTED' })}
                    className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm transition-all"
                  >
                    <CheckCircle className="w-4 h-4" />
                    <span>Set Status: Accepted</span>
                  </button>
                )}

                {/* Convert to Order */}
                {selectedQuotation.status === 'ACCEPTED' && (
                  <button
                    onClick={() => convertToOrderMutation.mutate(selectedQuotation.id)}
                    disabled={convertToOrderMutation.isPending}
                    className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm transition-all"
                  >
                    <ShoppingCart className="w-4 h-4" />
                    <span>Convert to Confirmed Order</span>
                  </button>
                )}

                {/* Edit Quotation */}
                <button
                  onClick={() => {
                    const q = selectedQuotation;
                    setSelectedQuotation(null);
                    openEditModal(q);
                  }}
                  className="px-3 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl text-xs flex items-center gap-1.5 transition-all"
                >
                  <Edit2 className="w-3.5 h-3.5" />
                  <span>Edit Quotation</span>
                </button>
              </div>

              <div className="flex items-center gap-2">
                {/* PDF Download (3 Templates) */}
                <button
                  onClick={() => setTemplateModalQuotation(selectedQuotation)}
                  disabled={downloadingPdfId === selectedQuotation.id}
                  className="px-4 py-2 bg-sky-50 hover:bg-sky-100 text-sky-800 border border-sky-200 font-bold rounded-xl text-xs flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
                  title="Choose from 3 Quotation Templates"
                >
                  <Download className={`w-4 h-4 text-sky-600 ${downloadingPdfId === selectedQuotation.id ? 'animate-bounce' : ''}`} />
                  <span>{downloadingPdfId === selectedQuotation.id ? 'Generating PDF...' : 'Download PDF (3 Templates)'}</span>
                </button>

                <button
                  onClick={() => setSelectedQuotation(null)}
                  className="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl text-xs"
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* REVIEW DISCOUNT MODAL */}
      {approvalModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-base font-bold text-slate-900">Commercial Review: {approvalModal.quotationNumber}</h2>
              <button onClick={() => setApprovalModal(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-3 bg-amber-50 border border-amber-200 rounded-xl text-xs text-amber-900 space-y-1">
              <div className="font-bold">Requested Concession: ₹{Number(approvalModal.additionalDiscountRequested).toLocaleString('en-IN')}</div>
              <div>Salesman: {approvalModal.salesman?.user?.fullName || 'Assigned Staff'}</div>
              <div>Reason: "{approvalModal.discountReason || 'No rationale specified'}"</div>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Administrative Action</label>
                <div className="grid grid-cols-3 gap-2">
                  {(['APPROVE', 'REJECT', 'REVISE'] as const).map((act) => (
                    <button
                      key={act}
                      type="button"
                      onClick={() => setApprovalAction(act)}
                      className={`py-2 text-xs font-bold rounded-xl border transition-all ${
                        approvalAction === act
                          ? act === 'APPROVE'
                            ? 'bg-teal-600 text-white border-teal-600 shadow-sm'
                            : act === 'REJECT'
                            ? 'bg-red-600 text-white border-red-600 shadow-sm'
                            : 'bg-amber-600 text-white border-amber-600 shadow-sm'
                          : 'bg-slate-50 text-slate-600 border-slate-200'
                      }`}
                    >
                      {act}
                    </button>
                  ))}
                </div>
              </div>

              {approvalAction === 'REVISE' && (
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Counter-Offer Discount (₹)</label>
                  <input
                    type="number"
                    value={revisedDiscount}
                    onChange={(e) => setRevisedDiscount(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              )}

              <div className="grid grid-cols-2 gap-2">
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">GST Slab to Apply</label>
                  <select
                    value={approvalTaxRate}
                    onChange={(e) => setApprovalTaxRate(Number(e.target.value))}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value={18}>18% (Standard Rate)</option>
                    <option value={12}>12% (Water Purifiers)</option>
                    <option value={5}>5% (Concessional / Spares)</option>
                    <option value={0}>0% (Exempted / Nil)</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 mb-1">Shipping Fee (₹)</label>
                  <input
                    type="number"
                    min="0"
                    value={approvalShipping}
                    onChange={(e) => setApprovalShipping(Number(e.target.value))}
                    placeholder="0"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono font-bold text-sky-700 focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {/* Profit summary for Super Admin */}
              <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-xs flex justify-between items-center font-mono">
                <div>
                  <div className="text-emerald-800 font-bold">Estimated Net Profit</div>
                  <div className="text-[10px] text-emerald-600 font-sans">Super Admin Confidential</div>
                </div>
                <div className="text-right">
                  <div className="text-emerald-950 font-bold text-sm">₹{Number(approvalModal.profit || 0).toLocaleString('en-IN')}</div>
                  <div className="text-[10px] text-emerald-700 font-sans">Margin: {approvalModal.profitMargin || 0}%</div>
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Approver Justification / Remarks</label>
                <textarea
                  rows={2}
                  value={approvalNotes}
                  onChange={(e) => setApprovalNotes(e.target.value)}
                  placeholder="Reason for decision..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setApprovalModal(null)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={reviewDiscountMutation.isPending}
                onClick={() =>
                  reviewDiscountMutation.mutate({
                    id: approvalModal.id,
                    action: approvalAction,
                    notes: approvalNotes,
                    revisedDiscount,
                    taxRate: approvalTaxRate,
                    shippingCharges: approvalShipping,
                  })
                }
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {reviewDiscountMutation.isPending ? 'Submitting...' : 'Submit Decision'}
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
              <h3 className="font-bold text-slate-900 text-base">Delete Quotation?</h3>
              <p className="text-xs text-slate-500 mt-1">
                Are you sure you want to delete this quotation and its line items? This action cannot be undone.
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
                disabled={deleteQuotationMutation.isPending}
                onClick={() => deleteQuotationMutation.mutate(deleteConfirmId)}
                className="flex-1 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {deleteQuotationMutation.isPending ? 'Deleting...' : 'Confirm Delete'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 3 Distinct Quotation Templates Picker Modal */}
      {templateModalQuotation && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full border border-slate-100 overflow-hidden">
            <div className="px-6 py-4 bg-gradient-to-r from-sky-900 to-indigo-900 text-white flex items-center justify-between">
              <div>
                <h3 className="text-base font-bold flex items-center gap-2">
                  <FileText className="w-5 h-5 text-sky-300" />
                  Select Quotation PDF Template
                </h3>
                <p className="text-xs text-sky-200 mt-0.5">
                  Quotation #{templateModalQuotation.quotationNumber || templateModalQuotation.id.slice(-6).toUpperCase()} • Choose your preferred printable layout
                </p>
              </div>
              <button
                onClick={() => setTemplateModalQuotation(null)}
                className="p-1.5 text-white/70 hover:text-white rounded-lg hover:bg-white/10"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-6 grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Template 1: Modern Corporate */}
              <div className="border border-sky-100 rounded-xl p-4 bg-sky-50/30 flex flex-col justify-between hover:border-sky-400 hover:shadow-md transition-all">
                <div>
                  <div className="w-full h-24 bg-gradient-to-br from-sky-950 to-blue-900 rounded-lg p-2.5 flex flex-col justify-between text-white mb-3 shadow-inner">
                    <div className="flex items-center justify-between">
                      <span className="text-[9px] font-bold tracking-widest text-sky-300 uppercase">Template 1</span>
                      <span className="text-[8px] bg-sky-500/30 px-1.5 py-0.5 rounded text-sky-200 font-semibold">Verified</span>
                    </div>
                    <div className="text-[11px] font-extrabold tracking-tight">Modern Corporate</div>
                    <div className="text-[8px] text-sky-200">Navy banner • Centered images • Pre-tax</div>
                  </div>
                  <h4 className="font-bold text-slate-800 text-sm">Modern Corporate</h4>
                  <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                    Deep navy branding, itemized table with centered product photos, verification badge, line items without GST.
                  </p>
                </div>
                <button
                  onClick={() => {
                    handleDownloadPdf(templateModalQuotation, '1');
                    setTemplateModalQuotation(null);
                  }}
                  disabled={downloadingPdfId === templateModalQuotation.id}
                  className="mt-4 w-full py-2 bg-sky-600 hover:bg-sky-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-sm transition-all"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download T1</span>
                </button>
              </div>

              {/* Template 2: Executive Clean Minimal */}
              <div className="border border-emerald-100 rounded-xl p-4 bg-emerald-50/30 flex flex-col justify-between hover:border-emerald-400 hover:shadow-md transition-all">
                <div>
                  <div className="w-full h-24 bg-gradient-to-br from-emerald-950 to-teal-900 rounded-lg p-2.5 flex flex-col justify-between text-white mb-3 shadow-inner">
                    <div className="flex items-center justify-between">
                      <span className="text-[9px] font-bold tracking-widest text-emerald-300 uppercase">Template 2</span>
                      <span className="text-[8px] bg-emerald-500/30 px-1.5 py-0.5 rounded text-emerald-200 font-semibold">Minimal</span>
                    </div>
                    <div className="text-[11px] font-extrabold tracking-tight">Executive Clean</div>
                    <div className="text-[8px] text-emerald-200">Official logo • Slate table • NEFT Remittance</div>
                  </div>
                  <h4 className="font-bold text-slate-800 text-sm">Executive Minimal</h4>
                  <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                    Clean white layout, official logo on left, soft slate table header, and comprehensive NEFT/RTGS banking remittance card.
                  </p>
                </div>
                <button
                  onClick={() => {
                    handleDownloadPdf(templateModalQuotation, '2');
                    setTemplateModalQuotation(null);
                  }}
                  disabled={downloadingPdfId === templateModalQuotation.id}
                  className="mt-4 w-full py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-sm transition-all"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download T2</span>
                </button>
              </div>

              {/* Template 3: GST Formal Wholesale */}
              <div className="border border-indigo-100 rounded-xl p-4 bg-indigo-50/30 flex flex-col justify-between hover:border-indigo-400 hover:shadow-md transition-all">
                <div>
                  <div className="w-full h-24 bg-gradient-to-br from-slate-900 to-indigo-950 rounded-lg p-2.5 flex flex-col justify-between text-white mb-3 shadow-inner">
                    <div className="flex items-center justify-between">
                      <span className="text-[9px] font-bold tracking-widest text-indigo-300 uppercase">Template 3</span>
                      <span className="text-[8px] bg-indigo-500/30 px-1.5 py-0.5 rounded text-indigo-200 font-semibold">Sec 31 GST</span>
                    </div>
                    <div className="text-[11px] font-extrabold tracking-tight">Formal Wholesale</div>
                    <div className="text-[8px] text-indigo-200">Double-border • HSN 84212190 • Tax schedule</div>
                  </div>
                  <h4 className="font-bold text-slate-800 text-sm">GST Formal Wholesale</h4>
                  <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">
                    Classic statutory double-border, consignor/consignee grid, HSN code 84212190, split CGST+SGST schedule, and words amount.
                  </p>
                </div>
                <button
                  onClick={() => {
                    handleDownloadPdf(templateModalQuotation, '3');
                    setTemplateModalQuotation(null);
                  }}
                  disabled={downloadingPdfId === templateModalQuotation.id}
                  className="mt-4 w-full py-2 bg-indigo-700 hover:bg-indigo-800 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 shadow-sm transition-all"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>Download T3</span>
                </button>
              </div>
            </div>

            <div className="px-6 py-3 bg-slate-50 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-500">
              <span>All 3 templates strictly fit on 1 page with pre-tax line items and 18% GST below subtotal.</span>
              <button
                onClick={() => setTemplateModalQuotation(null)}
                className="px-3 py-1 bg-white border border-slate-200 hover:bg-slate-100 rounded-lg font-bold text-slate-700"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
