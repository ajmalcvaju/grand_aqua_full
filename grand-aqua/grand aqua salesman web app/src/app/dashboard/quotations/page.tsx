'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  FileText,
  Plus,
  Search,
  Download,
  Eye,
  Clock,
  CheckCircle,
  XCircle,
  X,
  AlertCircle,
  Trash2,
  Camera,
  Building2,
  User,
  ShoppingBag,
  FileCheck,
} from 'lucide-react';

export default function SalesmanQuotationsPage() {
  const queryClient = useQueryClient();
  const [createModal, setCreateModal] = useState(false);
  const [selectedBuyerId, setSelectedBuyerId] = useState('');
  const [items, setItems] = useState<{ productId: string; quantity: number }[]>([]);
  const [discountRequested, setDiscountRequested] = useState(0);
  const [discountReason, setDiscountReason] = useState('');
  const [selectedQuotation, setSelectedQuotation] = useState<any>(null);
  const [downloadingPdfId, setDownloadingPdfId] = useState<string | null>(null);

  const { data: quotationsData, isLoading: quotesLoading } = useQuery({
    queryKey: ['salesman-quotations'],
    queryFn: () => api.get('/quotations'),
  });

  const { data: buyersData } = useQuery({
    queryKey: ['salesman-buyers-select'],
    queryFn: () => api.get('/buyers?limit=100'),
  });

  const { data: productsData } = useQuery({
    queryKey: ['products-select'],
    queryFn: () => api.get('/products?limit=100'),
  });

  const quotations = (quotationsData as any)?.quotations || [];
  const buyers = (buyersData as any)?.buyers || [];
  const products = (productsData as any)?.products || [];

  const handleDownloadPdf = async (q: any) => {
    if (!q?.id) return;
    try {
      setDownloadingPdfId(q.id);
      const res = await api.get(`/quotations/${q.id}/pdf`, {
        responseType: 'blob',
      });
      const blob = new Blob([res as any], { type: 'application/pdf' });
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `GrandAqua-Quotation-${q.quotationNumber || q.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch (err: any) {
      // Fallback direct download
      window.open(`/api/v1/quotations/${q.id}/pdf`, '_blank');
    } finally {
      setDownloadingPdfId(null);
    }
  };

  const createQuotationMutation = useMutation({
    mutationFn: (body: any) => api.post('/quotations', body),
    onSuccess: (data: any) => {
      queryClient.invalidateQueries({ queryKey: ['salesman-quotations'] });
      setCreateModal(false);
      setItems([]);
      setDiscountRequested(0);
      setDiscountReason('');
      if (data.status === 'PENDING_DISCOUNT_APPROVAL') {
        alert(`Quotation ${data.quotationNumber} submitted! Dispatched for Super Admin discount approval.`);
      } else {
        alert(`Quotation ${data.quotationNumber} generated and issued to buyer!`);
      }
    },
    onError: (err: any) => alert(`Error: ${err.message}`),
  });

  const addItem = (productId: string) => {
    if (!productId) return;
    setItems((prev) => [...prev, { productId, quantity: 1 }]);
  };

  const removeItem = (index: number) => {
    setItems((prev) => prev.filter((_, i) => i !== index));
  };

  const updateQuantity = (index: number, quantity: number) => {
    setItems((prev) =>
      prev.map((item, i) => (i === index ? { ...item, quantity: Math.max(1, quantity) } : item)),
    );
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Quotation Workspace</h1>
          <p className="text-sm text-slate-500">
            Generate customized commercial proposals with buyer-specific category rates and discount requests.
          </p>
        </div>

        <button
          onClick={() => {
            if (buyers.length > 0) setSelectedBuyerId(buyers[0].id);
            if (products.length > 0 && items.length === 0) {
              setItems([{ productId: products[0].id, quantity: 2 }]);
            }
            setCreateModal(true);
          }}
          className="flex items-center gap-2 px-4 py-2.5 bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold rounded-xl shadow-md transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>Prepare New Quotation</span>
        </button>
      </div>

      {/* Quotations List */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Quotation #</th>
                <th className="px-5 py-3.5">Buyer Shop</th>
                <th className="px-5 py-3.5">Items Count</th>
                <th className="px-5 py-3.5">Final Total</th>
                <th className="px-5 py-3.5">Discount Status</th>
                <th className="px-5 py-3.5">Quotation Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {quotesLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">Loading quotations...</td>
                </tr>
              ) : quotations.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">No quotations generated yet.</td>
                </tr>
              ) : (
                quotations.map((q: any) => (
                  <tr key={q.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-3.5">
                      <span className="font-mono font-bold text-teal-700">{q.quotationNumber}</span>
                      <div className="text-[10px] text-slate-400">
                        {new Date(q.createdAt).toLocaleDateString('en-IN', {
                          day: 'numeric',
                          month: 'short',
                          year: 'numeric',
                        })}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <div className="font-bold text-slate-800">{q.buyer?.businessName || q.buyer?.user?.fullName}</div>
                      <div className="text-[10px] text-slate-400">{q.buyer?.buyerType}</div>
                    </td>

                    <td className="px-5 py-3.5 font-semibold text-slate-700">
                      {q.items?.length || 0} product(s)
                    </td>

                    <td className="px-5 py-3.5 font-mono font-bold text-slate-900">
                      ₹{Number(q.finalTotal).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>

                    <td className="px-5 py-3.5 font-mono">
                      {Number(q.additionalDiscountRequested) > 0 ? (
                        <span className="text-amber-600 font-bold">
                          ₹{Number(q.additionalDiscountRequested).toLocaleString('en-IN')} ({q.discountApprovalStatus})
                        </span>
                      ) : (
                        <span className="text-slate-400">Standard</span>
                      )}
                    </td>

                    <td className="px-5 py-3.5">
                      <span className="px-2.5 py-1 bg-teal-50 text-teal-800 font-bold rounded-full text-[10px]">
                        {q.status}
                      </span>
                    </td>

                    <td className="px-5 py-3.5 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setSelectedQuotation(q)}
                          className="inline-flex items-center gap-1 px-2.5 py-1 text-teal-700 bg-teal-50 hover:bg-teal-100 rounded-lg font-bold transition-colors"
                          title="View Quotation"
                        >
                          <Eye className="w-3.5 h-3.5" /> View
                        </button>
                        <button
                          onClick={() => handleDownloadPdf(q)}
                          disabled={downloadingPdfId === q.id}
                          className="inline-flex items-center gap-1 px-2.5 py-1 text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-lg font-bold transition-colors disabled:opacity-50"
                          title="Download Quotation PDF"
                        >
                          <Download className="w-3.5 h-3.5 text-slate-600" />
                          <span>{downloadingPdfId === q.id ? '...' : 'PDF'}</span>
                        </button>
                      </div>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* View Quotation Modal with Itemized Breakdown & Product Images */}
      {selectedQuotation && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 space-y-6 max-h-[92vh] overflow-y-auto">
            {/* Header */}
            <div className="flex items-start justify-between border-b border-slate-100 pb-4">
              <div>
                <div className="flex items-center gap-3">
                  <h2 className="text-xl font-black text-slate-900 font-mono">
                    {selectedQuotation.quotationNumber}
                  </h2>
                  <span className="px-3 py-1 bg-teal-50 text-teal-800 font-bold rounded-full text-xs border border-teal-200">
                    {selectedQuotation.status}
                  </span>
                </div>
                <div className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                  <span>
                    Created: {new Date(selectedQuotation.createdAt).toLocaleDateString('en-IN', {
                      day: 'numeric',
                      month: 'short',
                      year: 'numeric',
                    })}
                  </span>
                  <span>•</span>
                  <span>Valid for: {selectedQuotation.validityDays || 15} Days</span>
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleDownloadPdf(selectedQuotation)}
                  disabled={downloadingPdfId === selectedQuotation.id}
                  className="px-3.5 py-1.5 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>{downloadingPdfId === selectedQuotation.id ? 'Generating...' : 'Download PDF'}</span>
                </button>
                <button
                  onClick={() => setSelectedQuotation(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100 transition-colors"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Buyer and Quotation Details */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs bg-slate-50 p-4 rounded-2xl border border-slate-200">
              <div>
                <span className="text-slate-400 font-bold block mb-1">PROSPECTIVE BUYER</span>
                <div className="font-bold text-slate-900 text-sm">
                  {selectedQuotation.buyer?.businessName || selectedQuotation.buyer?.user?.fullName}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Type: <strong>{selectedQuotation.buyer?.buyerType}</strong> • Tier: {selectedQuotation.buyer?.loyaltyTier || 'BRONZE'}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Contact: {selectedQuotation.buyer?.user?.phone || 'N/A'} • {selectedQuotation.buyer?.user?.email || ''}
                </div>
              </div>

              <div>
                <span className="text-slate-400 font-bold block mb-1">COMMERCIAL TERMS</span>
                <div className="text-slate-700 font-medium">
                  Payment: <strong>{selectedQuotation.paymentTerms || 'Payment on Delivery'}</strong>
                </div>
                <div className="text-slate-700 font-medium mt-1">
                  Validity: <strong>{selectedQuotation.validityDays || 15} calendar days</strong>
                </div>
                {selectedQuotation.buyerNotes && (
                  <div className="text-slate-500 text-[11px] mt-1 italic">
                    Notes: "{selectedQuotation.buyerNotes}"
                  </div>
                )}
              </div>
            </div>

            {/* Itemized Breakdown Table */}
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
                            {Number(it.totalPrice).toLocaleString('en-IN', {
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

            {/* Financial Summary */}
            <div className="p-4 bg-slate-900 text-white rounded-2xl flex flex-col sm:flex-row justify-between items-start sm:items-center font-mono gap-3">
              <div className="text-xs space-y-1">
                <div>Subtotal: ₹{Number(selectedQuotation.subtotal).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
                <div>GST (18%): ₹{Number(selectedQuotation.taxAmount || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
                {Number(selectedQuotation.additionalDiscountRequested) > 0 && (
                  <div className="text-amber-400">
                    Additional Concession: -₹{Number(selectedQuotation.additionalDiscountRequested).toLocaleString('en-IN', { minimumFractionDigits: 2 })} ({selectedQuotation.discountApprovalStatus})
                  </div>
                )}
              </div>
              <div className="text-left sm:text-right">
                <div className="text-[10px] text-slate-400 font-sans uppercase tracking-wider">Final Payable Total</div>
                <div className="text-2xl font-black text-teal-400">
                  ₹{Number(selectedQuotation.finalTotal).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Prepare Quotation Modal */}
      {createModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl border border-slate-100 space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-base font-bold text-slate-900">Prepare Trade Quotation</h2>
              <button onClick={() => setCreateModal(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                if (items.length === 0) {
                  alert('Please add at least one product.');
                  return;
                }
                createQuotationMutation.mutate({
                  buyerProfileId: selectedBuyerId,
                  items,
                  additionalDiscountRequested: Number(discountRequested),
                  discountReason,
                });
              }}
              className="space-y-4"
            >
              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Select Assigned Buyer</label>
                <select
                  required
                  value={selectedBuyerId}
                  onChange={(e) => setSelectedBuyerId(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-teal-500"
                >
                  {buyers.map((b: any) => (
                    <option key={b.id} value={b.id}>
                      {b.businessName || b.user?.fullName} ({b.buyerType}) — Tier: {b.loyaltyTier || 'BRONZE'}
                    </option>
                  ))}
                </select>
              </div>

              {/* Products Section */}
              <div className="space-y-2">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-slate-700">Line Items</label>
                  <button
                    type="button"
                    onClick={() => {
                      if (products.length > 0) addItem(products[0].id);
                    }}
                    className="text-xs text-teal-600 font-bold hover:underline"
                  >
                    + Add Another Product
                  </button>
                </div>

                {items.map((item, idx) => {
                  const prod = products.find((p: any) => p.id === item.productId);
                  const imgObj =
                    prod?.media?.find((m: any) => m.mediaType === 'IMAGE') ||
                    prod?.media?.[0];
                  let imgUrl = imgObj?.url || prod?.imageUrl;
                  if (imgUrl && imgUrl.startsWith('/uploads/')) {
                    imgUrl = `http://localhost:4000${imgUrl}`;
                  }

                  return (
                    <div key={idx} className="flex items-center gap-2 bg-slate-50 p-2.5 rounded-xl border border-slate-200">
                      {/* Product Thumbnail Preview */}
                      <div className="w-9 h-9 rounded-lg border border-slate-200 bg-white flex items-center justify-center shrink-0 overflow-hidden relative">
                        {imgUrl ? (
                          <img
                            src={imgUrl}
                            alt={prod?.name || 'Product'}
                            className="w-full h-full object-contain p-0.5"
                          />
                        ) : (
                          <div className="relative flex items-center justify-center w-full h-full">
                            <Camera className="w-3.5 h-3.5 text-slate-400" />
                            <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                              <div className="w-4 h-[1.5px] bg-slate-300 rotate-45 transform origin-center"></div>
                            </div>
                          </div>
                        )}
                      </div>

                      <select
                        value={item.productId}
                        onChange={(e) => {
                          const newProdId = e.target.value;
                          setItems((prev) =>
                            prev.map((it, i) => (i === idx ? { ...it, productId: newProdId } : it)),
                          );
                        }}
                        className="flex-1 px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-medium focus:outline-none"
                      >
                        {products.map((p: any) => (
                          <option key={p.id} value={p.id}>
                            {p.name} ({p.sku})
                          </option>
                        ))}
                      </select>

                      <div className="flex items-center gap-1">
                        <span className="text-[11px] text-slate-400 font-medium">Qty:</span>
                        <input
                          type="number"
                          min="1"
                          value={item.quantity}
                          onChange={(e) => updateQuantity(idx, Number(e.target.value))}
                          className="w-16 px-2 py-1.5 bg-white border border-slate-200 rounded-lg text-xs font-mono font-bold text-center"
                        />
                      </div>

                      <button
                        type="button"
                        onClick={() => removeItem(idx)}
                        className="p-1 text-slate-400 hover:text-red-500 rounded"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  );
                })}
              </div>

              {/* Additional Discount Request */}
              <div className="p-4 bg-amber-50/70 border border-amber-200 rounded-xl space-y-2">
                <div className="flex items-center gap-1.5 text-xs font-bold text-amber-900">
                  <AlertCircle className="w-4 h-4 text-amber-600" />
                  Request Additional Commercial Concession:
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                  <div>
                    <label className="block text-slate-600 mb-1 font-semibold">Discount Amount (₹)</label>
                    <input
                      type="number"
                      min="0"
                      value={discountRequested}
                      onChange={(e) => setDiscountRequested(Number(e.target.value))}
                      placeholder="0"
                      className="w-full px-3 py-1.5 bg-white border border-amber-300 rounded-xl text-xs font-mono font-bold"
                    />
                  </div>
                  <div>
                    <label className="block text-slate-600 mb-1 font-semibold">Justification Reason</label>
                    <input
                      type="text"
                      value={discountReason}
                      onChange={(e) => setDiscountReason(e.target.value)}
                      placeholder="e.g. Bulk order commitment..."
                      className="w-full px-3 py-1.5 bg-white border border-amber-300 rounded-xl text-xs"
                    />
                  </div>
                </div>
                <p className="text-[11px] text-amber-700 italic">
                  Note: Any additional discount requested will route through the Super Admin approval workflow.
                </p>
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setCreateModal(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createQuotationMutation.isPending}
                  className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
                >
                  {createQuotationMutation.isPending ? 'Generating...' : 'Issue / Submit Quotation'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
