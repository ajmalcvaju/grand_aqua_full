'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import { Settings, ShieldCheck, Users, Save, CheckCircle } from 'lucide-react';

export default function SettingsPage() {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<'COMPANY' | 'STAFF'>('COMPANY');

  const { data: settingsData, isLoading } = useQuery({
    queryKey: ['company-settings'],
    queryFn: () => api.get('/settings'),
  });

  const { data: staffData } = useQuery({
    queryKey: ['admin-staff'],
    queryFn: () => api.get('/settings/admin-staff'),
  });

  const settings = (settingsData as any) || {};
  const staff = (staffData as any) || [];

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight">System Settings & Administration</h1>
          <p className="text-sm text-slate-500">
            Configure company branding, GST taxation, currency (INR), and administrative role permissions.
          </p>
        </div>

        <div className="flex items-center gap-1.5 p-1 bg-white border border-slate-200 rounded-xl shadow-sm text-xs">
          <button
            onClick={() => setActiveTab('COMPANY')}
            className={`px-3 py-1.5 font-bold rounded-lg transition-all ${
              activeTab === 'COMPANY' ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Company Profile & Policies
          </button>
          <button
            onClick={() => setActiveTab('STAFF')}
            className={`px-3 py-1.5 font-bold rounded-lg transition-all ${
              activeTab === 'STAFF' ? 'bg-sky-600 text-white shadow-sm' : 'text-slate-600 hover:text-slate-900'
            }`}
          >
            Administrative Staff & RBAC
          </button>
        </div>
      </div>

      {activeTab === 'COMPANY' ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-6 shadow-sm max-w-3xl space-y-5">
          <h2 className="text-base font-bold text-slate-900 border-b border-slate-100 pb-3 flex items-center gap-2">
            <Settings className="w-5 h-5 text-sky-600" />
            Official Enterprise Details
          </h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
            <div>
              <label className="block font-bold text-slate-700 mb-1">Company Registered Name</label>
              <input
                type="text"
                readOnly
                value={settings.COMPANY_NAME || 'Grand Aqua'}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Brand Tagline</label>
              <input
                type="text"
                readOnly
                value={settings.COMPANY_TAGLINE || 'Pure | Safe | Healthy - Wholesale & Retail'}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">GSTIN (18% Water Purifier Standard)</label>
              <input
                type="text"
                readOnly
                value={settings.COMPANY_GSTIN || '07AAAAA0000A1Z5'}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono font-bold text-slate-800"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Operating Currency</label>
              <input
                type="text"
                readOnly
                value="INR (Indian Rupee - ₹)"
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Official Support Phone</label>
              <input
                type="text"
                readOnly
                value={settings.COMPANY_PHONE || '+91 98765 43210'}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800"
              />
            </div>

            <div>
              <label className="block font-bold text-slate-700 mb-1">Official Support Email</label>
              <input
                type="text"
                readOnly
                value={settings.COMPANY_EMAIL || 'support@grandaqua.com'}
                className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-semibold text-slate-800"
              />
            </div>
          </div>
        </div>
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
          <div className="p-5 border-b border-slate-100 flex items-center justify-between">
            <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
              <ShieldCheck className="w-5 h-5 text-sky-600" />
              Administrative Staff Accounts
            </h2>
          </div>

          <table className="w-full text-left text-xs">
            <thead className="bg-slate-50 border-b border-slate-200 text-slate-600 font-bold uppercase">
              <tr>
                <th className="px-5 py-3">Full Name</th>
                <th className="px-5 py-3">Email Address</th>
                <th className="px-5 py-3">System Role</th>
                <th className="px-5 py-3">Account Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {staff.map((s: any) => (
                <tr key={s.id} className="hover:bg-slate-50">
                  <td className="px-5 py-3.5 font-bold text-slate-800">{s.fullName}</td>
                  <td className="px-5 py-3.5 text-slate-600">{s.email}</td>
                  <td className="px-5 py-3.5">
                    <span className="px-2.5 py-1 bg-sky-50 text-sky-700 font-bold font-mono text-[11px] rounded-lg border border-sky-200">
                      {s.role}
                    </span>
                  </td>
                  <td className="px-5 py-3.5">
                    <span className="px-2 py-0.5 bg-emerald-50 text-emerald-700 font-bold text-[10px] rounded-full uppercase">
                      {s.status}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
