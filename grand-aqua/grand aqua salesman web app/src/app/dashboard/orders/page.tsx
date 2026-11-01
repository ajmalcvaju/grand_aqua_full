'use client';

import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  ShoppingCart,
  Clock,
  CheckCircle,
  Truck,
  Package,
  Eye,
  Download,
  X,
  Camera,
  FileText,
} from 'lucide-react';

export default function SalesmanOrdersPage() {
  const [selectedOrder, setSelectedOrder] = useState<any>(null);
  const [downloadingInvoiceId, setDownloadingInvoiceId] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['salesman-orders'],
    queryFn: () => api.get('/orders'),
  });

  const orders = (data as any)?.orders || [];

  const handleDownloadInvoicePdf = async (ord: any) => {
    if (!ord?.id) return;
    try {
      setDownloadingInvoiceId(ord.id);
      const res = await api.get(`/orders/${ord.id}/invoice-pdf`, {
        responseType: 'blob',
      });
      const blob = new Blob([res as any], { type: 'application/pdf' });
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `GrandAqua-Invoice-${ord.orderNumber || ord.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch {
      window.open(`/api/v1/orders/${ord.id}/invoice-pdf`, '_blank');
    } finally {
      setDownloadingInvoiceId(null);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Orders & Dispatch Pipeline</h1>
          <p className="text-sm text-slate-500">
            Orders placed by your assigned shops, live delivery status tracking, docket details, and GST invoices.
          </p>
        </div>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Order #</th>
                <th className="px-5 py-3.5">Buyer Shop</th>
                <th className="px-5 py-3.5">Line Items</th>
                <th className="px-5 py-3.5">Total Amount</th>
                <th className="px-5 py-3.5">Payment</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5">Docket / Tracking</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-slate-400">Loading orders...</td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={8} className="text-center py-12 text-slate-400">No orders recorded yet.</td>
                </tr>
              ) : (
                orders.map((ord: any) => (
                  <tr key={ord.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-3.5 font-mono font-bold text-teal-700">
                      <div>{ord.orderNumber}</div>
                      <div className="text-[10px] text-slate-400 font-sans font-normal">
                        {new Date(ord.createdAt).toLocaleDateString()}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <div className="font-bold text-slate-800">{ord.buyer?.businessName || ord.buyer?.user?.fullName}</div>
                      <div className="text-[10px] text-slate-400">{ord.buyer?.buyerType}</div>
                    </td>

                    <td className="px-5 py-3.5 font-semibold text-slate-700">
                      {ord.items?.length || 0} product(s)
                    </td>

                    <td className="px-5 py-3.5 font-mono font-bold text-slate-900">
                      ₹{Number(ord.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>

                    <td className="px-5 py-3.5">
                      <span className="px-2 py-0.5 bg-slate-100 text-slate-700 font-mono text-[10px] rounded-full uppercase font-bold">
                        {ord.paymentStatus}
                      </span>
                    </td>

                    <td className="px-5 py-3.5">
                      <span className="px-2.5 py-1 bg-teal-50 text-teal-800 font-bold text-[10px] rounded-full">
                        {ord.status}
                      </span>
                    </td>

                    <td className="px-5 py-3.5 font-mono text-slate-600">
                      {ord.trackingNumber ? (
                        <span className="font-bold text-teal-700">{ord.trackingNumber}</span>
                      ) : (
                        <span className="text-slate-400">Pending Dispatch</span>
                      )}
                    </td>

                    <td className="px-5 py-3.5 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setSelectedOrder(ord)}
                          className="px-2.5 py-1 bg-teal-50 text-teal-700 hover:bg-teal-100 font-bold rounded-lg transition-colors inline-flex items-center gap-1"
                        >
                          <Eye className="w-3.5 h-3.5" /> Details
                        </button>
                        <button
                          onClick={() => handleDownloadInvoicePdf(ord)}
                          disabled={downloadingInvoiceId === ord.id}
                          className="px-2.5 py-1 bg-slate-100 text-slate-700 hover:bg-slate-200 font-bold rounded-lg transition-colors inline-flex items-center gap-1 disabled:opacity-50"
                          title="Download GST Invoice"
                        >
                          <Download className="w-3.5 h-3.5" />
                          <span>{downloadingInvoiceId === ord.id ? '...' : 'Invoice'}</span>
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

      {/* Order Details & Items Modal */}
      {selectedOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 space-y-6 max-h-[92vh] overflow-y-auto">
            <div className="flex items-start justify-between border-b border-slate-100 pb-4">
              <div>
                <div className="flex items-center gap-3">
                  <h2 className="text-xl font-black text-slate-900 font-mono">{selectedOrder.orderNumber}</h2>
                  <span className="px-3 py-1 bg-teal-50 text-teal-800 font-bold rounded-full text-xs border border-teal-200">
                    {selectedOrder.status}
                  </span>
                </div>
                <div className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                  <span>Created: {new Date(selectedOrder.createdAt).toLocaleDateString()}</span>
                  <span>•</span>
                  <span>Payment: <strong>{selectedOrder.paymentStatus}</strong></span>
                  {selectedOrder.trackingNumber && (
                    <>
                      <span>•</span>
                      <span className="text-teal-700 font-mono font-bold">Docket: {selectedOrder.trackingNumber}</span>
                    </>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => handleDownloadInvoicePdf(selectedOrder)}
                  disabled={downloadingInvoiceId === selectedOrder.id}
                  className="px-3.5 py-1.5 bg-teal-600 hover:bg-teal-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>{downloadingInvoiceId === selectedOrder.id ? 'Generating...' : 'GST Invoice (PDF)'}</span>
                </button>
                <button
                  onClick={() => setSelectedOrder(null)}
                  className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Buyer and Shipping Details */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs bg-slate-50 p-4 rounded-2xl border border-slate-200">
              <div>
                <span className="text-slate-400 font-bold block mb-1">BUYER SHOP</span>
                <div className="font-bold text-slate-900 text-sm">
                  {selectedOrder.buyer?.businessName || selectedOrder.buyer?.user?.fullName}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Type: <strong>{selectedOrder.buyer?.buyerType}</strong> • Contact: {selectedOrder.buyer?.user?.phone || 'N/A'}
                </div>
              </div>

              <div>
                <span className="text-slate-400 font-bold block mb-1">SHIPPING DESTINATION</span>
                <div className="text-slate-700 font-medium">
                  {typeof selectedOrder.shippingAddress === 'object' && selectedOrder.shippingAddress !== null
                    ? `${selectedOrder.shippingAddress.addressLine || selectedOrder.shippingAddress.address || 'Address'}, ${selectedOrder.shippingAddress.city || ''} ${selectedOrder.shippingAddress.pincode || ''}`
                    : 'Standard Registered Address'}
                </div>
                {selectedOrder.deliveryNotes && (
                  <div className="text-slate-500 text-[11px] mt-1 italic">
                    Notes: "{selectedOrder.deliveryNotes}"
                  </div>
                )}
              </div>
            </div>

            {/* Itemized Table */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-bold text-xs uppercase tracking-wider text-slate-500">Purchased Products</h3>
                <span className="text-[11px] text-slate-400 font-medium">{selectedOrder.items?.length || 0} Products</span>
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
                    {(selectedOrder.items || []).map((it: any, idx: number) => {
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
                              {it.product?.category?.name || 'Grand Aqua RO System'}
                            </div>
                          </td>
                          <td className="px-3 py-3 text-center border-r border-slate-200">
                            <div className="font-bold text-slate-900">{Number(it.quantity).toFixed(0)}</div>
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
                            {Number(it.totalPrice || it.unitPrice * it.quantity).toLocaleString('en-IN', {
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
                      <td colSpan={5} className="px-4 py-2.5 text-right font-sans text-xs text-slate-700 border-r border-slate-200">
                        Total
                      </td>
                      <td className="px-3 py-2.5 text-right text-xs text-slate-900 font-mono font-black">
                        ₹{' '}
                        {Number(selectedOrder.subtotal || selectedOrder.finalAmount).toLocaleString('en-IN', {
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
                <div>Subtotal: ₹{Number(selectedOrder.subtotal || selectedOrder.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
                <div>GST (18%): ₹{Number(selectedOrder.taxTotal || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
              </div>
              <div className="text-left sm:text-right">
                <div className="text-[10px] text-slate-400 font-sans uppercase tracking-wider">Final Payable Total</div>
                <div className="text-2xl font-black text-teal-400">
                  ₹{Number(selectedOrder.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
