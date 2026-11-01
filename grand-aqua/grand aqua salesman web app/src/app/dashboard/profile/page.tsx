'use client';

import React, { useState } from 'react';
import { useAuth } from '@/lib/auth-context';
import { User, Award, MapPin, Building, CreditCard, CheckCircle } from 'lucide-react';

export default function SalesmanProfilePage() {
  const { user } = useAuth();
  const [bankName, setBankName] = useState('HDFC Bank');
  const [accountNumber, setAccountNumber] = useState('•••• •••• •••• 9876');
  const [ifsc, setIfsc] = useState('HDFC0001234');
  const [submitted, setSubmitted] = useState(false);

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h1 className="text-2xl font-black text-slate-900 tracking-tight">Salesman Profile & Settings</h1>
        <p className="text-sm text-slate-500">
          Manage your field credentials, review performance targets, and submit payout account details.
        </p>
      </div>

      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
        <h2 className="text-base font-bold text-slate-900 border-b border-slate-100 pb-3 flex items-center gap-2">
          <User className="w-5 h-5 text-teal-600" />
          Employment Information
        </h2>

        <div className="grid grid-cols-2 gap-4 text-xs">
          <div className="p-3 bg-slate-50 rounded-xl">
            <span className="text-slate-400 font-bold uppercase text-[10px]">Salesman Name</span>
            <p className="font-bold text-slate-800 text-sm mt-0.5">{user?.fullName || 'Amit Sharma'}</p>
          </div>
          <div className="p-3 bg-slate-50 rounded-xl">
            <span className="text-slate-400 font-bold uppercase text-[10px]">Employee Code</span>
            <p className="font-bold text-teal-700 text-sm font-mono mt-0.5">GA-SM-001</p>
          </div>
          <div className="p-3 bg-slate-50 rounded-xl">
            <span className="text-slate-400 font-bold uppercase text-[10px]">Email Address</span>
            <p className="font-semibold text-slate-800 mt-0.5">{user?.email || 'amit.sharma@grandaqua.com'}</p>
          </div>
          <div className="p-3 bg-slate-50 rounded-xl">
            <span className="text-slate-400 font-bold uppercase text-[10px]">Mobile Phone</span>
            <p className="font-semibold text-slate-800 mt-0.5">+91 98765 00001</p>
          </div>
        </div>
      </div>

      {/* Payout Banking Details Request */}
      <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm space-y-4">
        <h2 className="text-base font-bold text-slate-900 border-b border-slate-100 pb-3 flex items-center gap-2">
          <CreditCard className="w-5 h-5 text-teal-600" />
          Incentive Payout Bank Account
        </h2>

        {submitted ? (
          <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-xl text-emerald-800 text-xs flex items-center gap-2">
            <CheckCircle className="w-5 h-5 text-emerald-600 flex-shrink-0" />
            <span>Bank account modification request submitted to Accounts Manager for verification.</span>
          </div>
        ) : (
          <form
            onSubmit={(e) => {
              e.preventDefault();
              setSubmitted(true);
            }}
            className="space-y-3 text-xs"
          >
            <div>
              <label className="block font-bold text-slate-600 mb-1">Bank Name</label>
              <input
                type="text"
                required
                value={bankName}
                onChange={(e) => setBankName(e.target.value)}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-medium focus:outline-none focus:ring-2 focus:ring-teal-500"
              />
            </div>

            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="block font-bold text-slate-600 mb-1">Account Number</label>
                <input
                  type="text"
                  required
                  value={accountNumber}
                  onChange={(e) => setAccountNumber(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono font-medium focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
              </div>
              <div>
                <label className="block font-bold text-slate-600 mb-1">IFSC Code</label>
                <input
                  type="text"
                  required
                  value={ifsc}
                  onChange={(e) => setIfsc(e.target.value)}
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono uppercase font-bold focus:outline-none focus:ring-2 focus:ring-teal-500"
                />
              </div>
            </div>

            <div className="pt-2">
              <button
                type="submit"
                className="px-4 py-2 bg-teal-600 hover:bg-teal-700 text-white font-bold rounded-xl shadow-md transition-all"
              >
                Submit Bank Verification Request
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}
