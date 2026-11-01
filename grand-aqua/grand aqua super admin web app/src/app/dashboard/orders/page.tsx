'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  ShoppingCart,
  Search,
  Filter,
  CheckCircle,
  Clock,
  Truck,
  Package,
  XCircle,
  Eye,
  AlertCircle,
  X,
  Camera,
  Download,
  FileText,
  Send,
  Calendar,
  MessageSquare,
  ExternalLink,
  Share2,
} from 'lucide-react';

const ORDER_STATUSES = ['ALL', 'PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED'];

function getCarrierTrackingUrl(deliveryNotes: string, trackingNumber: string): string {
  const docket = (trackingNumber || '').trim();
  const notes = (deliveryNotes || '').toLowerCase();
  if (notes.includes('delhivery')) return `https://www.delhivery.com/track/package/${docket}`;
  if (notes.includes('blue dart') || notes.includes('bluedart')) return `https://www.bluedart.com/tracking?trackNumber=${docket}`;
  if (notes.includes('dtdc')) return `https://www.dtdc.in/tracking/shipment-tracking.asp?strCnno=${docket}`;
  if (notes.includes('v-trans') || notes.includes('vtrans')) return `https://vtransgroup.com/track-consignment/?lrno=${docket}`;
  return `https://grandaqua.com/tracking?docket=${docket}`;
}

export default function OrdersPage() {
  const queryClient = useQueryClient();
  const [selectedStatus, setSelectedStatus] = useState('ALL');
  const [search, setSearch] = useState('');
  const [statusModalOrder, setStatusModalOrder] = useState<any>(null);
  const [viewModalOrder, setViewModalOrder] = useState<any>(null);
  const [targetStatus, setTargetStatus] = useState('PROCESSING');
  const [trackingNumber, setTrackingNumber] = useState('');
  const [carrierName, setCarrierName] = useState('Delhivery Express');
  const [expectedDeliveryDate, setExpectedDeliveryDate] = useState('');
  const [statusReason, setStatusReason] = useState('');
  const [downloadingInvoiceId, setDownloadingInvoiceId] = useState<string | null>(null);
  const [templateModalOrder, setTemplateModalOrder] = useState<any | null>(null);
  const [sendNotifications, setSendNotifications] = useState(true);
  const [resendingAlert, setResendingAlert] = useState(false);
  const [alertFeedback, setAlertFeedback] = useState<string | null>(null);

  const { data, isLoading } = useQuery({
    queryKey: ['orders-list', selectedStatus, search],
    queryFn: () => {
      let url = `/orders?search=${encodeURIComponent(search)}`;
      if (selectedStatus !== 'ALL') url += `&status=${selectedStatus}`;
      return api.get(url);
    },
  });

  const orders = (data as any)?.orders || [];

  const handleDownloadInvoicePdf = async (ord: any, template: string = '1') => {
    if (!ord?.id) return;
    try {
      setDownloadingInvoiceId(ord.id);
      const res = await api.get(`/orders/${ord.id}/invoice-pdf?template=${template}`, {
        responseType: 'blob',
      });
      const blob = new Blob([res as any], { type: 'application/pdf' });
      const downloadUrl = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = downloadUrl;
      link.download = `GrandAqua-Invoice-T${template}-${ord.orderNumber || ord.id}.pdf`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(downloadUrl);
    } catch {
      window.open(`/api/v1/orders/${ord.id}/invoice-pdf?template=${template}`, '_blank');
    } finally {
      setDownloadingInvoiceId(null);
    }
  };

  const updateStatusMutation = useMutation({
    mutationFn: async (vars: any): Promise<any> => {
      if (vars.status === 'SHIPPED') {
        const res = await api.put(`/orders/${vars.id}/dispatch`, {
          trackingNumber: vars.trackingNumber,
          carrierName: vars.carrierName,
          expectedDeliveryDate: vars.expectedDeliveryDate,
          notes: vars.reason,
        });
        return res.data;
      }
      const res = await api.put(`/orders/${vars.id}/status`, {
        status: vars.status,
        reason: vars.reason,
        trackingNumber: vars.trackingNumber,
      });
      return res.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders-list'] });
      setStatusModalOrder(null);
      alert('Order status updated. Buyer notified.');
    },
    onError: (err: any) => alert(`Error: ${err.message}`),
  });

  const getStatusBadge = (status: string) => {
    switch (status) {
      case 'DELIVERED':
        return <span className="px-2.5 py-1 bg-emerald-100 text-emerald-800 font-bold rounded-full text-[11px]">Delivered</span>;
      case 'SHIPPED':
        return <span className="px-2.5 py-1 bg-sky-100 text-sky-800 font-bold rounded-full text-[11px]">Shipped</span>;
      case 'PROCESSING':
        return <span className="px-2.5 py-1 bg-indigo-100 text-indigo-800 font-bold rounded-full text-[11px]">Processing</span>;
      case 'CONFIRMED':
        return <span className="px-2.5 py-1 bg-teal-100 text-teal-800 font-bold rounded-full text-[11px]">Confirmed</span>;
      case 'CANCELLED':
        return <span className="px-2.5 py-1 bg-red-100 text-red-800 font-bold rounded-full text-[11px]">Cancelled</span>;
      default:
        return <span className="px-2.5 py-1 bg-amber-100 text-amber-800 font-bold rounded-full text-[11px]">Pending</span>;
    }
  };

  const handleResendNotification = async (orderId: string) => {
    setResendingAlert(true);
    setAlertFeedback(null);
    try {
      await api.post(`/orders/${orderId}/resend-dispatch-notification`, { channel: 'ALL' });
      setAlertFeedback('WhatsApp & SMS dispatch alerts resent to customer with live tracking & GST invoice link!');
      setTimeout(() => setAlertFeedback(null), 4000);
    } catch (err: any) {
      alert(`Failed to resend notification: ${err.response?.data?.message || err.message}`);
    } finally {
      setResendingAlert(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Order Management</h1>
          <p className="text-sm text-slate-500">
            Track order status progression, dispatch logistics, delivery confirmations, and GST invoice generation.
          </p>
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search order #, buyer..."
            className="w-full pl-9 pr-4 py-2 bg-white border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
          />
        </div>
      </div>

      {/* Tabs */}
      <div className="flex flex-wrap gap-1.5 p-1 bg-white border border-slate-200 rounded-xl shadow-sm text-xs">
        {ORDER_STATUSES.map((st) => (
          <button
            key={st}
            onClick={() => setSelectedStatus(st)}
            className={`px-3 py-1.5 font-bold rounded-lg transition-all ${
              selectedStatus === st ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            {st === 'ALL' ? 'All Orders' : st}
          </button>
        ))}
      </div>

      {/* Orders Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Order #</th>
                <th className="px-5 py-3.5">Buyer</th>
                <th className="px-5 py-3.5">Products Qty</th>
                <th className="px-5 py-3.5">Final Amount</th>
                <th className="px-5 py-3.5">Payment</th>
                <th className="px-5 py-3.5">Status</th>
                <th className="px-5 py-3.5 text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {isLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">Loading orders...</td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">No orders found.</td>
                </tr>
              ) : (
                orders.map((ord: any) => (
                  <tr key={ord.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-3.5">
                      <span className="font-mono font-bold text-sky-700">{ord.orderNumber}</span>
                      <div className="text-[10px] text-slate-400">
                        {new Date(ord.createdAt).toLocaleDateString()}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <div className="font-bold text-slate-800">{ord.buyer?.businessName || ord.buyer?.user?.fullName}</div>
                      <div className="text-[10px] text-slate-500 font-mono">
                        {ord.buyer?.user?.phone} • {ord.salesman?.user?.fullName ? `Sales: ${ord.salesman.user.fullName}` : 'Direct'}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <span className="font-semibold text-slate-700">{ord.items?.length || 0} Line Item(s)</span>
                    </td>

                    <td className="px-5 py-3.5 font-mono font-bold text-slate-900">
                      ₹{Number(ord.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                      <div className="mt-1 inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-50 text-emerald-800 border border-emerald-200">
                        <span>Profit: ₹{Number(ord.profit || 0).toLocaleString('en-IN')}</span>
                        {ord.profitMargin !== undefined && (
                          <span className="text-emerald-600 font-medium">({ord.profitMargin}%)</span>
                        )}
                      </div>
                    </td>

                    <td className="px-5 py-3.5">
                      <span
                        className={`inline-block px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${
                          ord.paymentStatus === 'PAID'
                            ? 'bg-emerald-50 text-emerald-700'
                            : ord.paymentStatus === 'PARTIALLY_PAID'
                            ? 'bg-amber-50 text-amber-700'
                            : 'bg-slate-100 text-slate-600'
                        }`}
                      >
                        {ord.paymentStatus}
                      </span>
                      <div className="text-[10px] text-slate-400 font-mono mt-0.5">{ord.paymentMethod}</div>
                    </td>

                    <td className="px-5 py-3.5">{getStatusBadge(ord.status)}</td>

                    <td className="px-5 py-3.5 text-right">
                      <div className="flex items-center justify-end gap-1.5">
                        <button
                          onClick={() => setViewModalOrder(ord)}
                          className="px-2.5 py-1 bg-slate-100 text-slate-700 hover:bg-slate-200 font-bold rounded-lg transition-colors inline-flex items-center gap-1"
                        >
                          <Eye className="w-3.5 h-3.5" />
                          <span>Details</span>
                        </button>
                        <button
                          onClick={() => setTemplateModalOrder(ord)}
                          disabled={downloadingInvoiceId === ord.id}
                          className="px-2.5 py-1 bg-sky-50 text-sky-700 hover:bg-sky-100 font-bold rounded-lg transition-colors inline-flex items-center gap-1 disabled:opacity-50"
                          title="Download GST Tax Invoice (Choose from 3 Templates)"
                        >
                          <Download className="w-3.5 h-3.5" />
                          <span>{downloadingInvoiceId === ord.id ? '...' : 'Invoice'}</span>
                        </button>
                        <button
                          onClick={() => {
                            setStatusModalOrder(ord);
                            setTargetStatus(ord.status === 'PENDING' ? 'CONFIRMED' : ord.status === 'CONFIRMED' ? 'PROCESSING' : ord.status === 'PROCESSING' ? 'SHIPPED' : 'DELIVERED');
                            setTrackingNumber(ord.trackingNumber || '');
                            setCarrierName('Delhivery Express');
                            setExpectedDeliveryDate('');
                            setStatusReason('');
                          }}
                          className="px-2.5 py-1 bg-teal-50 text-teal-700 hover:bg-teal-100 font-bold rounded-lg transition-colors"
                        >
                          Status
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

      {/* Update / Dispatch Status Modal */}
      {statusModalOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-bold text-slate-900">
                  {targetStatus === 'SHIPPED' ? 'Dispatch Order & Generate Invoice' : 'Update Order Status'}
                </h2>
                <p className="text-xs text-sky-600 font-mono">{statusModalOrder.orderNumber}</p>
              </div>
              <button onClick={() => setStatusModalOrder(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Target Status</label>
                <select
                  value={targetStatus}
                  onChange={(e) => setTargetStatus(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="CONFIRMED">CONFIRMED (Order Verified)</option>
                  <option value="PROCESSING">PROCESSING (Assembly / Packing)</option>
                  <option value="SHIPPED">SHIPPED (Dispatch & Generate GST Invoice)</option>
                  <option value="DELIVERED">DELIVERED (Final Fulfillment / Closed)</option>
                  <option value="CANCELLED">CANCELLED</option>
                </select>
              </div>

              {targetStatus === 'SHIPPED' && (
                <>
                  <div>
                    <label className="block text-xs font-bold text-slate-600 mb-1">Transport / Carrier Partner</label>
                    <select
                      value={carrierName}
                      onChange={(e) => setCarrierName(e.target.value)}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                    >
                      <option value="Delhivery Express">Delhivery Express</option>
                      <option value="Blue Dart Express">Blue Dart Express</option>
                      <option value="V-Trans Cargo Logistics">V-Trans Cargo Logistics</option>
                      <option value="DTDC Surface">DTDC Surface</option>
                      <option value="Direct Grand Aqua Fleet">Direct Grand Aqua Fleet</option>
                      <option value="Local Transport">Local Transport</option>
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-600 mb-1">Courier / Tracking Docket #</label>
                    <input
                      type="text"
                      required
                      value={trackingNumber}
                      onChange={(e) => setTrackingNumber(e.target.value)}
                      placeholder="e.g. DLV-GA-998877"
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>

                  <div>
                    <label className="block text-xs font-bold text-slate-600 mb-1">Expected Delivery Date</label>
                    <input
                      type="date"
                      value={expectedDeliveryDate}
                      onChange={(e) => setExpectedDeliveryDate(e.target.value)}
                      className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>

                  {/* Automated WhatsApp & SMS Dispatch Alerts */}
                  <div className="bg-emerald-50/80 border border-emerald-200/90 rounded-xl p-3 space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <span className="p-1 bg-emerald-600 text-white rounded-lg">
                          <MessageSquare className="w-3.5 h-3.5" />
                        </span>
                        <div>
                          <div className="text-xs font-bold text-slate-900">WhatsApp & SMS Dispatch Alerts</div>
                          <div className="text-[11px] text-emerald-800">Direct courier tracking link + GST invoice PDF link</div>
                        </div>
                      </div>
                      <input
                        type="checkbox"
                        checked={sendNotifications}
                        onChange={(e) => setSendNotifications(e.target.checked)}
                        className="w-4 h-4 text-emerald-600 rounded focus:ring-emerald-500 cursor-pointer"
                      />
                    </div>
                    {sendNotifications && (
                      <div className="bg-white p-2.5 rounded-lg border border-emerald-100 text-[11px] text-slate-600 space-y-1">
                        <div className="font-semibold text-emerald-800 flex items-center gap-1.5">
                          <CheckCircle className="w-3 h-3 text-emerald-600 shrink-0" />
                          <span>Includes live tracking link for {carrierName || 'carrier'}</span>
                        </div>
                        <div className="font-semibold text-emerald-800 flex items-center gap-1.5">
                          <CheckCircle className="w-3 h-3 text-emerald-600 shrink-0" />
                          <span>Includes direct official GST Tax Invoice download link</span>
                        </div>
                        <div className="text-[10px] text-slate-400 font-mono mt-1 pt-1 border-t border-slate-100">
                          Recipient Phone: {statusModalOrder?.buyer?.user?.phone || 'Customer Phone'}
                        </div>
                      </div>
                    )}
                  </div>
                </>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Status Notes / Remarks</label>
                <input
                  type="text"
                  value={statusReason}
                  onChange={(e) => setStatusReason(e.target.value)}
                  placeholder="e.g. Packed with reinforced crating from Gurugram Central Depot..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-3 pt-2">
              <button
                type="button"
                onClick={() => setStatusModalOrder(null)}
                className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={updateStatusMutation.isPending || (targetStatus === 'SHIPPED' && !trackingNumber.trim())}
                onClick={() =>
                  updateStatusMutation.mutate({
                    id: statusModalOrder.id,
                    status: targetStatus,
                    trackingNumber,
                    carrierName,
                    expectedDeliveryDate,
                    reason: statusReason,
                  })
                }
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {updateStatusMutation.isPending ? 'Updating...' : targetStatus === 'SHIPPED' ? 'Confirm Dispatch & Invoice' : 'Confirm Update'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* View Details Modal with Itemized Breakdown & GST Invoice Download */}
      {viewModalOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-3xl max-w-4xl w-full p-6 shadow-2xl border border-slate-100 space-y-6 max-h-[92vh] overflow-y-auto">
            <div className="flex items-start justify-between border-b border-slate-100 pb-4">
              <div>
                <div className="flex items-center gap-3">
                  <h2 className="text-xl font-black text-slate-900 font-mono">{viewModalOrder.orderNumber}</h2>
                  {getStatusBadge(viewModalOrder.status)}
                </div>
                <div className="text-xs text-slate-500 mt-1 flex items-center gap-3">
                  <span>Created: {new Date(viewModalOrder.createdAt).toLocaleDateString()}</span>
                  <span>•</span>
                  <span>Payment: <strong>{viewModalOrder.paymentMethod}</strong> ({viewModalOrder.paymentStatus})</span>
                  {viewModalOrder.trackingNumber && (
                    <>
                      <span>•</span>
                      <span className="text-sky-700 font-mono font-bold">Docket: {viewModalOrder.trackingNumber}</span>
                    </>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2">
                <button
                  onClick={() => setTemplateModalOrder(viewModalOrder)}
                  disabled={downloadingInvoiceId === viewModalOrder.id}
                  className="px-3.5 py-1.5 bg-sky-600 hover:bg-sky-700 text-white rounded-xl text-xs font-bold flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
                  title="Choose from 3 GST Invoice Templates"
                >
                  <Download className="w-3.5 h-3.5" />
                  <span>{downloadingInvoiceId === viewModalOrder.id ? 'Generating...' : 'GST Invoice (3 Templates)'}</span>
                </button>
                <button onClick={() => setViewModalOrder(null)} className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100">
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>

            {/* Buyer and Shipping Details */}
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs bg-slate-50 p-4 rounded-2xl border border-slate-200">
              <div>
                <span className="text-slate-400 font-bold block mb-1">BUYER ACCOUNT</span>
                <div className="font-bold text-slate-900 text-sm">
                  {viewModalOrder.buyer?.businessName || viewModalOrder.buyer?.user?.fullName}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Type: <strong>{viewModalOrder.buyer?.buyerType}</strong> • Contact: {viewModalOrder.buyer?.user?.phone || 'N/A'}
                </div>
                <div className="text-slate-500 mt-0.5">
                  Sales Staff: <strong>{viewModalOrder.salesman?.user?.fullName || 'Direct Company Account'}</strong>
                </div>
              </div>

              <div>
                <span className="text-slate-400 font-bold block mb-1">SHIPPING DESTINATION</span>
                <div className="text-slate-700 font-medium">
                  {typeof viewModalOrder.shippingAddress === 'object' && viewModalOrder.shippingAddress !== null
                    ? `${viewModalOrder.shippingAddress.addressLine || viewModalOrder.shippingAddress.address || 'Address'}, ${viewModalOrder.shippingAddress.city || ''} ${viewModalOrder.shippingAddress.pincode || ''}`
                    : 'Standard Registered Address'}
                </div>
                {viewModalOrder.deliveryNotes && (
                  <div className="text-slate-500 text-[11px] mt-1 italic">
                    Notes: "{viewModalOrder.deliveryNotes}"
                  </div>
                )}
              </div>
            </div>

            {/* Automated Dispatch & Logistics Alert Tracking */}
            {viewModalOrder.trackingNumber && (
              <div className="bg-emerald-50/70 border border-emerald-200 rounded-2xl p-4 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[10px] font-black bg-emerald-600 text-white uppercase tracking-wider">
                      <Truck className="w-3 h-3" /> Dispatched
                    </span>
                    <span className="font-bold text-xs text-slate-900">
                      {viewModalOrder.deliveryNotes?.includes('Carrier: ')
                        ? viewModalOrder.deliveryNotes.split('Carrier: ')[1].split('.')[0]
                        : 'Carrier Partner'}
                    </span>
                    <span className="text-xs font-mono font-bold text-emerald-800 bg-emerald-100/80 px-2 py-0.5 rounded-md">
                      #{viewModalOrder.trackingNumber}
                    </span>
                  </div>
                  <div className="text-[11px] text-emerald-800 flex items-center gap-2 font-medium">
                    <CheckCircle className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                    <span>Automated WhatsApp & SMS Notifications Dispatched (Tracking + GST Tax Invoice Linked)</span>
                  </div>
                  {alertFeedback && (
                    <div className="text-xs font-bold text-emerald-700 bg-emerald-100 px-2 py-1 rounded-md animate-pulse">
                      {alertFeedback}
                    </div>
                  )}
                </div>

                <div className="flex items-center gap-2 w-full sm:w-auto shrink-0">
                  <a
                    href={getCarrierTrackingUrl(
                      viewModalOrder.deliveryNotes || '',
                      viewModalOrder.trackingNumber,
                    )}
                    target="_blank"
                    rel="noreferrer"
                    className="px-3 py-1.5 bg-white hover:bg-emerald-100 text-emerald-800 border border-emerald-300 text-xs font-bold rounded-xl flex items-center gap-1.5 shadow-sm transition-all"
                  >
                    <ExternalLink className="w-3.5 h-3.5" />
                    <span>Track Shipment</span>
                  </a>

                  <button
                    type="button"
                    disabled={resendingAlert}
                    onClick={() => handleResendNotification(viewModalOrder.id)}
                    className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
                  >
                    <Send className="w-3.5 h-3.5" />
                    <span>{resendingAlert ? 'Resending...' : 'Resend WhatsApp/SMS'}</span>
                  </button>
                </div>
              </div>
            )}

            {/* Purchased Items Table with Product Images matching Quotation layout */}
            <div>
              <div className="flex items-center justify-between mb-2">
                <h3 className="font-bold text-xs uppercase tracking-wider text-slate-500">Purchased Goods & Equipment</h3>
                <span className="text-[11px] text-slate-400 font-medium">{viewModalOrder.items?.length || 0} Products</span>
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
                    {(viewModalOrder.items || []).map((it: any, idx: number) => {
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
                              {it.product?.category?.name || 'Grand Aqua Genuine RO System'}
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
                        {Number(viewModalOrder.subtotal || viewModalOrder.finalAmount).toLocaleString('en-IN', {
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
                <div>Subtotal: ₹{Number(viewModalOrder.subtotal || viewModalOrder.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
                <div>GST ({viewModalOrder.taxRate || 18}%): ₹{Number(viewModalOrder.taxTotal || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
                {Number(viewModalOrder.discountTotal) > 0 && (
                  <div className="text-emerald-400">
                    Discount Concession: -₹{Number(viewModalOrder.discountTotal).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                  </div>
                )}
              </div>
              <div className="text-left sm:text-right">
                <div className="text-[10px] text-slate-400 font-sans uppercase tracking-wider">Final Payable Total</div>
                <div className="text-2xl font-black text-sky-400">
                  ₹{Number(viewModalOrder.finalAmount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                </div>
              </div>
            </div>

            {/* Super Admin Confidential Profit Card */}
            <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl flex justify-between items-center text-xs font-mono">
              <div>
                <span className="font-bold text-emerald-900 block">Super Admin Net Profit</span>
                <span className="text-[10px] text-emerald-700 font-sans">Confidential • Pre-tax revenue minus purchase cost of items</span>
              </div>
              <div className="text-right">
                <span className="text-sm font-black text-emerald-950">₹{Number(viewModalOrder.profit || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</span>
                <span className="text-[10px] text-emerald-700 block font-sans">Margin: {viewModalOrder.profitMargin || 0}%</span>
              </div>
            </div>

            {/* Actions */}
            <div className="flex items-center justify-between pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setTemplateModalOrder(viewModalOrder)}
                disabled={downloadingInvoiceId === viewModalOrder.id}
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl flex items-center gap-1.5 shadow-sm transition-all disabled:opacity-50"
              >
                <Download className="w-3.5 h-3.5" />
                <span>{downloadingInvoiceId === viewModalOrder.id ? 'Generating...' : 'Download GST Invoice (Choose Template)'}</span>
              </button>
              <div className="space-x-2">
                <button
                  type="button"
                  onClick={() => setViewModalOrder(null)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Close
                </button>
                <button
                  type="button"
                  onClick={() => {
                    const ord = viewModalOrder;
                    setViewModalOrder(null);
                    setStatusModalOrder(ord);
                    setTargetStatus(ord.status === 'PENDING' ? 'CONFIRMED' : ord.status === 'CONFIRMED' ? 'PROCESSING' : ord.status === 'PROCESSING' ? 'SHIPPED' : 'DELIVERED');
                    setTrackingNumber(ord.trackingNumber || '');
                    setCarrierName('Delhivery Express');
                    setExpectedDeliveryDate('');
                    setStatusReason('');
                  }}
                  className="px-4 py-2 bg-slate-800 hover:bg-slate-900 text-white text-xs font-bold rounded-xl shadow-md"
                >
                  Change Status / Dispatch
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* 3 Distinct Invoice Templates Picker Modal */}
      {templateModalOrder && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl shadow-2xl max-w-2xl w-full border border-slate-100 overflow-hidden">
            <div className="px-6 py-4 bg-gradient-to-r from-sky-900 to-indigo-900 text-white flex items-center justify-between">
              <div>
                <h3 className="text-base font-bold flex items-center gap-2">
                  <FileText className="w-5 h-5 text-sky-300" />
                  Select GST Invoice Template
                </h3>
                <p className="text-xs text-sky-200 mt-0.5">
                  Order #{templateModalOrder.orderNumber || templateModalOrder.id.slice(-6).toUpperCase()} • Choose your preferred printable layout
                </p>
              </div>
              <button
                onClick={() => setTemplateModalOrder(null)}
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
                    Deep navy branding, itemized table with centered product photos, dispatch verified badge, and dark payable badge.
                  </p>
                </div>
                <button
                  onClick={() => {
                    handleDownloadInvoicePdf(templateModalOrder, '1');
                    setTemplateModalOrder(null);
                  }}
                  disabled={downloadingInvoiceId === templateModalOrder.id}
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
                    handleDownloadInvoicePdf(templateModalOrder, '2');
                    setTemplateModalOrder(null);
                  }}
                  disabled={downloadingInvoiceId === templateModalOrder.id}
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
                    handleDownloadInvoicePdf(templateModalOrder, '3');
                    setTemplateModalOrder(null);
                  }}
                  disabled={downloadingInvoiceId === templateModalOrder.id}
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
                onClick={() => setTemplateModalOrder(null)}
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
