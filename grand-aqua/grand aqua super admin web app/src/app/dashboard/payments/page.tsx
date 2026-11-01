'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  DollarSign,
  Plus,
  Search,
  Filter,
  CheckCircle,
  Clock,
  CreditCard,
  Building,
  User,
  X,
  Zap,
  Copy,
  Check,
  ShieldCheck,
  Radio,
} from 'lucide-react';

export default function PaymentsPage() {
  const queryClient = useQueryClient();
  const [addModalOpen, setAddModalOpen] = useState(false);
  const [gatewayModalOpen, setGatewayModalOpen] = useState(false);
  const [buyerId, setBuyerId] = useState('');
  const [orderId, setOrderId] = useState('');
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('UPI');
  const [txnRef, setTxnRef] = useState('');
  const [notes, setNotes] = useState('');

  // Gateway Simulation State
  const [simProvider, setSimProvider] = useState<'RAZORPAY' | 'CASHFREE'>('RAZORPAY');
  const [simBuyerId, setSimBuyerId] = useState('');
  const [simOrderNumber, setSimOrderNumber] = useState('');
  const [simAmount, setSimAmount] = useState('5000');
  const [simulating, setSimulating] = useState(false);
  const [simSuccessMsg, setSimSuccessMsg] = useState<string | null>(null);
  const [copiedKey, setCopiedKey] = useState<string | null>(null);

  const { data: paymentsData, isLoading: paymentsLoading } = useQuery({
    queryKey: ['payments-list'],
    queryFn: () => api.get('/payments'),
  });

  const { data: receivables } = useQuery({
    queryKey: ['receivables-summary'],
    queryFn: () => api.get('/payments/receivables-summary'),
  });

  const { data: buyersData } = useQuery({
    queryKey: ['buyers-select'],
    queryFn: () => api.get('/buyers?limit=100'),
  });

  const payments = (paymentsData as any)?.payments || [];
  const buyers = (buyersData as any)?.buyers || [];

  const recordPaymentMutation = useMutation({
    mutationFn: (body: any) => api.post('/payments', body),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['payments-list'] });
      queryClient.invalidateQueries({ queryKey: ['receivables-summary'] });
      queryClient.invalidateQueries({ queryKey: ['buyers-list'] });
      setAddModalOpen(false);
      setAmount('');
      setTxnRef('');
      setNotes('');
      alert('Payment recorded and reconciled against buyer balances successfully.');
    },
    onError: (err: any) => alert(`Error: ${err.message}`),
  });

  const copyToClipboard = (text: string, key: string) => {
    navigator.clipboard.writeText(text);
    setCopiedKey(key);
    setTimeout(() => setCopiedKey(null), 2500);
  };

  const handleSimulateWebhook = async () => {
    if (!simAmount || Number(simAmount) <= 0) {
      alert('Please enter a valid payment collection amount');
      return;
    }
    setSimulating(true);
    setSimSuccessMsg(null);
    try {
      const res = await api.post('/payments/webhooks/simulate', {
        provider: simProvider,
        amount: Number(simAmount),
        buyerProfileId: simBuyerId || (buyers[0]?.id || undefined),
        orderNumber: simOrderNumber.trim() || undefined,
      });
      queryClient.invalidateQueries({ queryKey: ['payments-list'] });
      queryClient.invalidateQueries({ queryKey: ['receivables-summary'] });
      setSimSuccessMsg(
        `Successfully received & reconciled ${simProvider} webhook! Payment #${res.data?.data?.result?.paymentNumber || 'GA-PAY'} recorded.`,
      );
      setTimeout(() => setSimSuccessMsg(null), 5000);
    } catch (err: any) {
      alert(`Webhook simulation failed: ${err.response?.data?.message || err.message}`);
    } finally {
      setSimulating(false);
    }
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">Payments & Receivables</h1>
          <p className="text-sm text-slate-500">
            Record settlements, reconcile outstanding balances, replenish credit limits, and audit transaction records.
          </p>
        </div>

        <div className="flex items-center gap-2.5">
          <button
            onClick={() => {
              if (buyers.length > 0 && !simBuyerId) setSimBuyerId(buyers[0].id);
              setGatewayModalOpen(true);
            }}
            className="flex items-center gap-2 px-3.5 py-2.5 bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold rounded-xl shadow-sm transition-all"
          >
            <Zap className="w-3.5 h-3.5 text-amber-400" />
            <span>Gateway Webhooks (Razorpay / Cashfree)</span>
          </button>

          <button
            onClick={() => {
              if (buyers.length > 0) setBuyerId(buyers[0].id);
              setAddModalOpen(true);
            }}
            className="flex items-center gap-2 px-4 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-md shadow-emerald-600/20 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Record Payment Entry</span>
          </button>
        </div>
      </div>

      {/* Receivables Summary Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-5">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Total Market Receivables</span>
          <div className="text-2xl font-black text-amber-600 mt-2 font-mono">
            ₹{Number((receivables as any)?.totalOutstanding || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
          </div>
          <p className="text-xs text-slate-500 mt-1">Pending payments across {(receivables as any)?.count || 0} business accounts</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-sm md:col-span-2">
          <span className="text-xs font-bold text-slate-400 uppercase tracking-wider">Top Outstanding Debtors</span>
          <div className="mt-2 flex flex-wrap gap-2">
            {((receivables as any)?.debtors || []).slice(0, 4).map((d: any) => (
              <div key={d.id} className="p-2 bg-slate-50 border border-slate-200 rounded-xl text-xs flex items-center gap-2">
                <span className="font-bold text-slate-800">{d.businessName || d.user?.fullName}</span>
                <span className="text-amber-600 font-mono font-bold">₹{Number(d.outstandingBalance).toLocaleString('en-IN')}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Payments History Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase tracking-wider">
              <tr>
                <th className="px-5 py-3.5">Payment #</th>
                <th className="px-5 py-3.5">Buyer</th>
                <th className="px-5 py-3.5">Amount</th>
                <th className="px-5 py-3.5">Method</th>
                <th className="px-5 py-3.5">Txn Reference</th>
                <th className="px-5 py-3.5">Date</th>
                <th className="px-5 py-3.5">Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {paymentsLoading ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">Loading payment ledger...</td>
                </tr>
              ) : payments.length === 0 ? (
                <tr>
                  <td colSpan={7} className="text-center py-12 text-slate-400">No payment records found.</td>
                </tr>
              ) : (
                payments.map((p: any) => (
                  <tr key={p.id} className="hover:bg-slate-50/80 transition-colors">
                    <td className="px-5 py-3.5">
                      <span className="font-mono font-bold text-emerald-700">{p.paymentNumber}</span>
                    </td>

                    <td className="px-5 py-3.5 font-bold text-slate-800">
                      {p.buyer?.businessName || p.buyer?.user?.fullName}
                    </td>

                    <td className="px-5 py-3.5 font-mono font-bold text-slate-900">
                      ₹{Number(p.amount).toLocaleString('en-IN', { minimumFractionDigits: 2 })}
                    </td>

                    <td className="px-5 py-3.5 font-semibold text-slate-700">
                      {p.gatewayProvider === 'RAZORPAY' || p.transactionReference?.startsWith('pay_') ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 bg-sky-100 text-sky-800 rounded-md font-bold text-[11px]">
                          <Zap className="w-3 h-3 text-sky-600" />
                          <span>Razorpay</span>
                        </span>
                      ) : p.gatewayProvider === 'CASHFREE' || p.transactionReference?.startsWith('cf_') ? (
                        <span className="inline-flex items-center gap-1 px-2.5 py-0.5 bg-violet-100 text-violet-800 rounded-md font-bold text-[11px]">
                          <Zap className="w-3 h-3 text-violet-600" />
                          <span>Cashfree</span>
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 bg-slate-100 rounded-md font-mono text-[11px]">{p.paymentMethod}</span>
                      )}
                    </td>

                    <td className="px-5 py-3.5 font-mono text-slate-500">
                      {p.transactionReference ? (
                        <span className="bg-slate-100 px-1.5 py-0.5 rounded text-[11px] font-semibold text-slate-700">
                          {p.transactionReference}
                        </span>
                      ) : (
                        <span className="text-slate-400 italic">Manual Entry</span>
                      )}
                    </td>

                    <td className="px-5 py-3.5 text-slate-500">
                      {new Date(p.paymentDate).toLocaleDateString()}
                    </td>

                    <td className="px-5 py-3.5">
                      <span className="px-2.5 py-1 bg-emerald-100 text-emerald-800 font-bold rounded-full text-[10px]">
                        {p.paymentStatus}
                      </span>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Record Payment Modal */}
      {addModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <h2 className="text-base font-bold text-slate-900">Record Payment Settlement</h2>
              <button onClick={() => setAddModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form
              onSubmit={(e) => {
                e.preventDefault();
                recordPaymentMutation.mutate({
                  buyerProfileId: buyerId,
                  orderId: orderId || undefined,
                  amount: Number(amount),
                  paymentMethod,
                  transactionReference: txnRef || undefined,
                  notes,
                });
              }}
              className="space-y-3"
            >
              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Select Buyer</label>
                <select
                  required
                  value={buyerId}
                  onChange={(e) => setBuyerId(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  {buyers.map((b: any) => (
                    <option key={b.id} value={b.id}>
                      {b.businessName || b.user?.fullName} ({b.buyerType}) — Bal: ₹{Number(b.outstandingBalance).toLocaleString('en-IN')}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Payment Amount (INR)</label>
                <input
                  type="number"
                  required
                  min="1"
                  step="0.01"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="50000"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Payment Mode</label>
                <select
                  value={paymentMethod}
                  onChange={(e) => setPaymentMethod(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                >
                  <option value="UPI">UPI / QR Code</option>
                  <option value="BANK_TRANSFER">NEFT / RTGS / IMPS Bank Transfer</option>
                  <option value="CASH">Cash Deposit</option>
                  <option value="CHEQUE">Cheque / Demand Draft</option>
                  <option value="CARD">Credit / Debit Card</option>
                </select>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Bank UTR / Transaction Reference</label>
                <input
                  type="text"
                  value={txnRef}
                  onChange={(e) => setTxnRef(e.target.value)}
                  placeholder="e.g. UTR-9988221100"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-600 mb-1">Internal Notes</label>
                <input
                  type="text"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Settlement received via HDFC Current Account"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div className="flex items-center justify-end gap-3 pt-2">
                <button
                  type="button"
                  onClick={() => setAddModalOpen(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={recordPaymentMutation.isPending}
                  className="px-4 py-2 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
                >
                  {recordPaymentMutation.isPending ? 'Reconciling...' : 'Confirm Payment'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Gateway Webhooks & Live Simulation Modal */}
      {gatewayModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-xl w-full p-6 shadow-2xl border border-slate-100 space-y-5 max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2.5">
                <div className="p-2 bg-amber-500/10 text-amber-600 rounded-xl">
                  <Zap className="w-5 h-5" />
                </div>
                <div>
                  <h2 className="text-base font-black text-slate-900">Payment Gateway Webhook Handlers</h2>
                  <p className="text-xs text-slate-500">Automated collection listeners for Razorpay and Cashfree</p>
                </div>
              </div>
              <button onClick={() => setGatewayModalOpen(false)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Active Endpoints Section */}
            <div className="space-y-3">
              <div className="text-xs font-bold text-slate-600 uppercase tracking-wider">Live Webhook Endpoints</div>

              <div className="bg-slate-50 border border-slate-200 rounded-xl p-3.5 space-y-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-sky-100 text-sky-800">POST</span>
                    <span className="font-bold text-xs text-slate-800">Razorpay Webhook Endpoint</span>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      copyToClipboard('http://localhost:4000/api/v1/payments/webhooks/razorpay', 'rzp')
                    }
                    className="flex items-center gap-1 text-[11px] font-bold text-sky-600 hover:text-sky-700"
                  >
                    {copiedKey === 'rzp' ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedKey === 'rzp' ? 'Copied!' : 'Copy URL'}</span>
                  </button>
                </div>
                <code className="text-[11px] text-slate-600 bg-white px-2 py-1 rounded block border border-slate-200 font-mono select-all">
                  http://localhost:4000/api/v1/payments/webhooks/razorpay
                </code>
                <div className="text-[10px] text-slate-400">
                  Header: <span className="font-mono">x-razorpay-signature</span> • Events: <span className="font-mono">payment.captured, order.paid</span>
                </div>
              </div>

              <div className="bg-slate-50 border border-slate-200 rounded-xl p-3.5 space-y-1.5">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-violet-100 text-violet-800">POST</span>
                    <span className="font-bold text-xs text-slate-800">Cashfree Webhook Endpoint</span>
                  </div>
                  <button
                    type="button"
                    onClick={() =>
                      copyToClipboard('http://localhost:4000/api/v1/payments/webhooks/cashfree', 'cf')
                    }
                    className="flex items-center gap-1 text-[11px] font-bold text-violet-600 hover:text-violet-700"
                  >
                    {copiedKey === 'cf' ? <Check className="w-3.5 h-3.5 text-emerald-600" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedKey === 'cf' ? 'Copied!' : 'Copy URL'}</span>
                  </button>
                </div>
                <code className="text-[11px] text-slate-600 bg-white px-2 py-1 rounded block border border-slate-200 font-mono select-all">
                  http://localhost:4000/api/v1/payments/webhooks/cashfree
                </code>
                <div className="text-[10px] text-slate-400">
                  Headers: <span className="font-mono">x-webhook-signature, x-webhook-timestamp</span> • Event: <span className="font-mono">PAYMENT_SUCCESS_WEBHOOK</span>
                </div>
              </div>
            </div>

            {/* Test Simulation Section */}
            <div className="border-t border-slate-100 pt-4 space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-900 flex items-center gap-1.5">
                    <ShieldCheck className="w-4 h-4 text-emerald-600" />
                    <span>Simulate Inbound Payment Collection</span>
                  </div>
                  <p className="text-[11px] text-slate-500">Test webhook reception, credit replenishment, and order allocation</p>
                </div>
              </div>

              {simSuccessMsg && (
                <div className="p-3 bg-emerald-50 border border-emerald-200 rounded-xl text-xs font-bold text-emerald-800 flex items-center gap-2">
                  <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
                  <span>{simSuccessMsg}</span>
                </div>
              )}

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Gateway Provider</label>
                  <select
                    value={simProvider}
                    onChange={(e: any) => setSimProvider(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value="RAZORPAY">Razorpay</option>
                    <option value="CASHFREE">Cashfree</option>
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Amount to Collect (₹)</label>
                  <input
                    type="number"
                    value={simAmount}
                    onChange={(e) => setSimAmount(e.target.value)}
                    placeholder="5000"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Target Buyer Account</label>
                  <select
                    value={simBuyerId}
                    onChange={(e) => setSimBuyerId(e.target.value)}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-medium focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    {buyers.map((b: any) => (
                      <option key={b.id} value={b.id}>
                        {b.businessName} ({b.buyerId})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-[11px] font-bold text-slate-600 mb-1">Order # (Optional)</label>
                  <input
                    type="text"
                    value={simOrderNumber}
                    onChange={(e) => setSimOrderNumber(e.target.value)}
                    placeholder="e.g. GA-ORD-2026-0001"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setGatewayModalOpen(false)}
                  className="px-4 py-2 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-xl"
                >
                  Close
                </button>
                <button
                  type="button"
                  disabled={simulating}
                  onClick={handleSimulateWebhook}
                  className="px-4 py-2 bg-slate-900 hover:bg-black text-white text-xs font-bold rounded-xl shadow-md flex items-center gap-1.5 transition-all disabled:opacity-50"
                >
                  <Zap className="w-3.5 h-3.5 text-amber-400" />
                  <span>{simulating ? 'Processing Webhook...' : `Simulate ${simProvider} Collection`}</span>
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
