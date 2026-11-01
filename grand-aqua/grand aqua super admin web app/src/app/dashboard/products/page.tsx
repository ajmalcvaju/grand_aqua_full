'use client';

import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '@/lib/api';
import {
  Package,
  Plus,
  Search,
  Edit2,
  Trash2,
  Eye,
  Boxes,
  Video,
  Box,
  Image as ImageIcon,
  CheckCircle,
  X,
  Droplet,
  ExternalLink,
  Shield,
  Layers,
  Sparkles,
  Upload,
  Loader2,
  CheckCircle2,
} from 'lucide-react';

export interface QuantityPriceSlab {
  minQuantity: number;
  maxQuantity?: number | null;
  price: number;
}

interface ProductModalState {
  isOpen: boolean;
  mode: 'create' | 'edit';
  id?: string;
  name: string;
  sku: string;
  categoryId: string;
  brand: string;
  shortDescription: string;
  fullDescription: string;
  imageUrl: string;
  videoUrl: string;
  model3dUrl: string;
  distributorPrice: number;
  wholesalerPrice: number;
  dealerPrice: number;
  customerPrice: number;
  purchasePrice: number;
  stock: number;
  isQuantityPricingEnabled: boolean;
  quantityPricingSlabs: QuantityPriceSlab[];
  warrantyDetails: string;
  isFeatured: boolean;
}

const initialModalState: ProductModalState = {
  isOpen: false,
  mode: 'create',
  name: '',
  sku: '',
  categoryId: '',
  brand: 'Grand Aqua',
  shortDescription: '',
  fullDescription: '',
  imageUrl: '',
  videoUrl: '',
  model3dUrl: '',
  distributorPrice: 0,
  wholesalerPrice: 0,
  dealerPrice: 0,
  customerPrice: 0,
  purchasePrice: 0,
  stock: 50,
  isQuantityPricingEnabled: false,
  quantityPricingSlabs: [],
  warrantyDetails: '1 Year Manufacturer Warranty',
  isFeatured: false,
};

export default function ProductsPage() {
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');
  const [modalState, setModalState] = useState<ProductModalState>(initialModalState);
  const [viewingMediaProduct, setViewingMediaProduct] = useState<any>(null);
  const [mediaActiveTab, setMediaActiveTab] = useState<'image' | 'video' | '3d'>('image');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);
  const [uploadingField, setUploadingField] = useState<'image' | 'video' | '3d' | null>(null);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [quickCategoryModal, setQuickCategoryModal] = useState<{
    open: boolean;
    id?: string;
    name: string;
    description: string;
  } | null>(null);

  const saveQuickCategoryMutation = useMutation({
    mutationFn: async (data: { id?: string; name: string; description?: string }) => {
      if (data.id) {
        return api.put(`/products/categories/${data.id}`, { name: data.name, description: data.description });
      } else {
        return api.post('/products/categories', { name: data.name, description: data.description });
      }
    },
    onSuccess: (saved: any) => {
      queryClient.invalidateQueries({ queryKey: ['products-categories'] });
      const catId = saved?.id || saved?.data?.id;
      if (catId) {
        setModalState((prev) => ({ ...prev, categoryId: catId }));
      }
      setQuickCategoryModal(null);
    },
    onError: (err: any) => alert(`Error saving category: ${err.message}`),
  });

  const handleFileUpload = async (file: File, field: 'image' | 'video' | '3d') => {
    if (!file) return;
    setUploadingField(field);
    setUploadError(null);
    try {
      const formData = new FormData();
      formData.append('file', file);
      const res: any = await api.post('/upload', formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
      const uploadedUrl = res.url || res.relativePath;
      if (field === 'image') setModalState((prev) => ({ ...prev, imageUrl: uploadedUrl }));
      else if (field === 'video') setModalState((prev) => ({ ...prev, videoUrl: uploadedUrl }));
      else if (field === '3d') setModalState((prev) => ({ ...prev, model3dUrl: uploadedUrl }));
    } catch (err: any) {
      setUploadError(`Failed to upload ${field}: ${err.message}`);
    } finally {
      setUploadingField(null);
    }
  };

  // Fetch Categories
  const { data: categoriesData } = useQuery({
    queryKey: ['products-categories'],
    queryFn: () => api.get('/products/categories'),
  });
  const categories = (categoriesData as any) || [];

  // Fetch Products
  const { data: productsData, isLoading } = useQuery({
    queryKey: ['products-list', search, selectedCategory],
    queryFn: () => {
      let url = `/products?search=${encodeURIComponent(search)}`;
      if (selectedCategory) url += `&categoryId=${encodeURIComponent(selectedCategory)}`;
      return api.get(url);
    },
  });
  const products = (productsData as any)?.products || [];

  // Create Product Mutation
  const createProductMutation = useMutation({
    mutationFn: (vars: any) => api.post('/products', vars),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products-list'] });
      setModalState(initialModalState);
      alert('Product created successfully with 4-tier pricing & media!');
    },
    onError: (err: any) => alert(`Failed to create product: ${err.message}`),
  });

  // Update Product Mutation
  const updateProductMutation = useMutation({
    mutationFn: (vars: any) => api.put(`/products/${vars.id}`, vars),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products-list'] });
      setModalState(initialModalState);
      alert('Product updated successfully!');
    },
    onError: (err: any) => alert(`Failed to update product: ${err.message}`),
  });

  // Delete Product Mutation
  const deleteProductMutation = useMutation({
    mutationFn: (id: string) => api.delete(`/products/${id}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products-list'] });
      setDeleteConfirmId(null);
      alert('Product deleted successfully.');
    },
    onError: (err: any) => alert(`Failed to delete product: ${err.message}`),
  });

  const openCreateModal = () => {
    setModalState({
      ...initialModalState,
      isOpen: true,
      mode: 'create',
      categoryId: categories.length > 0 ? categories[0].id : '',
    });
  };

  const openEditModal = (prod: any) => {
    const imgObj = prod.media?.find((m: any) => m.mediaType === 'IMAGE');
    const vidObj = prod.media?.find((m: any) => m.mediaType === 'VIDEO');
    const m3dObj = prod.media?.find((m: any) => m.mediaType === '3D_MODEL');

    setModalState({
      isOpen: true,
      mode: 'edit',
      id: prod.id,
      name: prod.name || '',
      sku: prod.sku || '',
      categoryId: prod.categoryId || (categories.length > 0 ? categories[0].id : ''),
      brand: prod.brand || 'Grand Aqua',
      shortDescription: prod.shortDescription || '',
      fullDescription: prod.fullDescription || '',
      imageUrl: imgObj?.url || '',
      videoUrl: vidObj?.url || '',
      model3dUrl: m3dObj?.url || '',
      distributorPrice: Number(prod.pricing?.distributorPrice || 0),
      wholesalerPrice: Number(prod.pricing?.wholesalerPrice || 0),
      dealerPrice: Number(prod.pricing?.dealerPrice || 0),
      customerPrice: Number(prod.pricing?.customerPrice || 0),
      purchasePrice: Number(prod.purchasePrice ?? prod.pricing?.purchasePrice ?? 0),
      stock: prod.stockQuantity ?? prod.inventory?.currentStock ?? 50,
      isQuantityPricingEnabled: Boolean(prod.isQuantityPricingEnabled),
      quantityPricingSlabs: Array.isArray(prod.quantityPricingSlabs) ? prod.quantityPricingSlabs : [],
      warrantyDetails: prod.warrantyDetails || '1 Year Manufacturer Warranty',
      isFeatured: !!prod.isFeatured,
    });
  };

  const openMediaModal = (prod: any) => {
    setViewingMediaProduct(prod);
    const has3d = prod.media?.some((m: any) => m.mediaType === '3D_MODEL');
    const hasVideo = prod.media?.some((m: any) => m.mediaType === 'VIDEO');
    if (has3d) {
      setMediaActiveTab('3d');
    } else if (hasVideo) {
      setMediaActiveTab('video');
    } else {
      setMediaActiveTab('image');
    }
  };

  const previewUploadedMedia = (type: 'image' | 'video' | '3d') => {
    setViewingMediaProduct({
      name: modalState.name || 'Product Media Preview',
      sku: modalState.sku || 'DRAFT-PREVIEW',
      category: categories.find((c: any) => c.id === modalState.categoryId),
      media: [
        ...(modalState.imageUrl ? [{ mediaType: 'IMAGE', url: modalState.imageUrl }] : []),
        ...(modalState.videoUrl ? [{ mediaType: 'VIDEO', url: modalState.videoUrl }] : []),
        ...(modalState.model3dUrl ? [{ mediaType: '3D_MODEL', url: modalState.model3dUrl }] : []),
      ],
    });
    setMediaActiveTab(type);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!modalState.name.trim()) {
      alert('Product name is required.');
      return;
    }
    if (!modalState.categoryId) {
      alert('Please select a category.');
      return;
    }

    const payload: any = {
      name: modalState.name.trim(),
      sku: modalState.sku.trim() || undefined,
      categoryId: modalState.categoryId,
      brand: modalState.brand,
      shortDescription: modalState.shortDescription.trim(),
      fullDescription: modalState.fullDescription.trim(),
      imageUrl: modalState.imageUrl.trim() || undefined,
      videoUrl: modalState.videoUrl.trim() || undefined,
      model3dUrl: modalState.model3dUrl.trim() || undefined,
      distributorPrice: Number(modalState.distributorPrice) || 0,
      wholesalerPrice: Number(modalState.wholesalerPrice) || 0,
      dealerPrice: Number(modalState.dealerPrice) || 0,
      customerPrice: Number(modalState.customerPrice) || 0,
      purchasePrice: Number(modalState.purchasePrice) || 0,
      stock: Number(modalState.stock) || 0,
      stockQuantity: Number(modalState.stock) || 0,
      isQuantityPricingEnabled: modalState.isQuantityPricingEnabled,
      quantityPricingSlabs: modalState.isQuantityPricingEnabled
        ? modalState.quantityPricingSlabs
            .filter((s) => Number(s.price) > 0 && Number(s.minQuantity) >= 1)
            .map((s) => ({
              minQuantity: Number(s.minQuantity),
              maxQuantity: s.maxQuantity ? Number(s.maxQuantity) : null,
              price: Number(s.price),
            }))
        : [],
      warrantyDetails: modalState.warrantyDetails,
      isFeatured: modalState.isFeatured,
    };

    if (modalState.mode === 'create') {
      createProductMutation.mutate(payload);
    } else if (modalState.id) {
      updateProductMutation.mutate({ id: modalState.id, ...payload });
    }
  };

  return (
    <div className="space-y-6">
      {/* Top Banner & Actions */}
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-black text-slate-900 tracking-tight flex items-center gap-2">
            <Package className="w-6 h-6 text-sky-600" />
            Product Management & 4-Tier Pricing
          </h1>
          <p className="text-sm text-slate-500">
            Full catalog CRUD with independent pricing for Customers, Dealers, Wholesalers, and Distributors, plus Image, Video, and 3D Model support.
          </p>
        </div>

        <div className="flex items-center gap-3 w-full sm:w-auto">
          <button
            onClick={openCreateModal}
            className="flex-1 sm:flex-none px-4 py-2.5 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl shadow-md flex items-center justify-center gap-1.5 transition-all"
          >
            <Plus className="w-4 h-4" />
            <span>Add New Product</span>
          </button>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="bg-white p-4 rounded-2xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-center justify-between gap-4">
        <div className="relative w-full md:w-80">
          <Search className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
          <input
            type="text"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search by SKU, product name, or specs..."
            className="w-full pl-9 pr-4 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs focus:outline-none focus:ring-2 focus:ring-sky-500 font-medium"
          />
        </div>

        <div className="flex items-center gap-3 w-full md:w-auto">
          <select
            value={selectedCategory}
            onChange={(e) => setSelectedCategory(e.target.value)}
            className="px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-semibold text-slate-700 focus:outline-none focus:ring-2 focus:ring-sky-500 w-full md:w-48"
          >
            <option value="">All Categories</option>
            {categories.map((cat: any) => (
              <option key={cat.id} value={cat.id}>
                {cat.name} ({cat._count?.products || 0})
              </option>
            ))}
          </select>

          <span className="text-xs text-slate-400 font-mono whitespace-nowrap">
            Total: <strong>{products.length}</strong> items
          </span>
        </div>
      </div>

      {/* Products Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        {isLoading ? (
          <div className="col-span-full py-16 text-center text-slate-400">Loading catalog...</div>
        ) : products.length === 0 ? (
          <div className="col-span-full py-16 text-center bg-white rounded-2xl border border-dashed border-slate-300 p-8">
            <Package className="w-12 h-12 text-slate-300 mx-auto mb-2" />
            <h3 className="font-bold text-slate-700 text-sm">No products found</h3>
            <p className="text-xs text-slate-500 mt-1">Click "Add New Product" to register your first purifier or spare part.</p>
            <button
              onClick={openCreateModal}
              className="mt-4 px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-xl"
            >
              Create Product Now
            </button>
          </div>
        ) : (
          products.map((prod: any) => {
            const imgMedia = prod.media?.find((m: any) => m.mediaType === 'IMAGE');
            const videoMedia = prod.media?.find((m: any) => m.mediaType === 'VIDEO');
            const model3dMedia = prod.media?.find((m: any) => m.mediaType === '3D_MODEL');

            return (
              <div
                key={prod.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden flex flex-col justify-between hover:shadow-md transition-shadow group"
              >
                <div>
                  {/* Media Header / Thumbnail */}
                  <div className="h-48 bg-slate-100 relative overflow-hidden flex items-center justify-center">
                    {imgMedia?.url ? (
                      <img
                        src={imgMedia.url}
                        alt={prod.name}
                        className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
                      />
                    ) : (
                      <div className="text-center text-slate-400">
                        <Droplet className="w-12 h-12 text-sky-400 mx-auto mb-1 opacity-50" />
                        <span className="text-xs font-mono">No Image</span>
                      </div>
                    )}

                    {/* SKU badge */}
                    <span className="absolute top-3 left-3 px-2.5 py-1 bg-slate-900/80 backdrop-blur-sm text-white font-mono text-[10px] font-bold rounded-lg shadow">
                      {prod.sku}
                    </span>

                    {/* Media Type Badges */}
                    <div className="absolute top-3 right-3 flex items-center gap-1">
                      {model3dMedia && (
                        <span className="px-2 py-0.5 bg-purple-600 text-white font-bold text-[9px] rounded-md shadow flex items-center gap-1">
                          <Box className="w-3 h-3" /> 3D
                        </span>
                      )}
                      {videoMedia && (
                        <span className="px-2 py-0.5 bg-rose-600 text-white font-bold text-[9px] rounded-md shadow flex items-center gap-1">
                          <Video className="w-3 h-3" /> Video
                        </span>
                      )}
                      {prod.isFeatured && (
                        <span className="px-2 py-0.5 bg-amber-400 text-amber-950 font-bold text-[9px] rounded-md shadow">
                          ★ Featured
                        </span>
                      )}
                    </div>

                    {/* Quick Media Viewer Button */}
                    <button
                      onClick={() => openMediaModal(prod)}
                      className="absolute bottom-3 right-3 px-2.5 py-1 bg-white/90 hover:bg-white text-slate-800 text-[10px] font-bold rounded-lg shadow-sm flex items-center gap-1 backdrop-blur-sm transition-all"
                    >
                      <Eye className="w-3 h-3 text-sky-600" />
                      <span>View Media & 3D</span>
                    </button>
                  </div>

                  {/* Body Details */}
                  <div className="p-5 space-y-3">
                    <div>
                      <span className="text-[10px] font-bold uppercase text-sky-600 tracking-wider">
                        {prod.category?.name || 'Water Purifier'}
                      </span>
                      <h3 className="font-bold text-slate-900 text-sm mt-0.5 line-clamp-1">{prod.name}</h3>
                      <p className="text-xs text-slate-500 line-clamp-2 mt-1">
                        {prod.shortDescription || 'High performance RO + UV + UF water filtration technology.'}
                      </p>
                    </div>

                    {/* 4 Independent Buyer Prices Table */}
                    <div className="bg-slate-50 rounded-xl p-3 border border-slate-100 text-xs space-y-1.5 font-mono">
                      <div className="text-[10px] font-bold uppercase tracking-wider text-slate-400 mb-1 flex items-center justify-between">
                        <span>4-Tier Pricing (Excl. 18% GST)</span>
                        <span className="text-sky-600 font-semibold font-sans">Multi-Tier</span>
                      </div>
                      <div className="flex justify-between items-center text-sky-800">
                        <span className="text-slate-500 font-sans">1. Distributor:</span>
                        <span className="font-bold">₹{Number(prod.pricing?.distributorPrice || 0).toLocaleString('en-IN')}</span>
                      </div>
                      <div className="flex justify-between items-center text-cyan-800">
                        <span className="text-slate-500 font-sans">2. Wholesaler:</span>
                        <span className="font-bold">₹{Number(prod.pricing?.wholesalerPrice || 0).toLocaleString('en-IN')}</span>
                      </div>
                      <div className="flex justify-between items-center text-teal-800">
                        <span className="text-slate-500 font-sans">3. Dealer:</span>
                        <span className="font-bold">₹{Number(prod.pricing?.dealerPrice || 0).toLocaleString('en-IN')}</span>
                      </div>
                      <div className="flex justify-between items-center text-slate-900 pt-1 border-t border-slate-200">
                        <span className="text-slate-600 font-sans font-semibold">4. Customer:</span>
                        <span className="font-bold">₹{Number(prod.pricing?.customerPrice || 0).toLocaleString('en-IN')}</span>
                      </div>
                      <div className="flex justify-between items-center text-amber-900 pt-1 border-t border-dashed border-amber-200 bg-amber-50/70 -mx-3 -mb-3 p-2 rounded-b-xl">
                        <span className="text-amber-800 font-sans font-semibold text-[11px]">Purchase (Cost):</span>
                        <div className="text-right">
                          <span className="font-bold text-amber-950">₹{Number(prod.purchasePrice ?? prod.pricing?.purchasePrice ?? 0).toLocaleString('en-IN')}</span>
                          <span className="text-[10px] text-amber-700 ml-1.5 font-sans font-medium">
                            (Margin: ₹{Math.max(0, Number(prod.pricing?.distributorPrice || 0) - Number(prod.purchasePrice ?? prod.pricing?.purchasePrice ?? 0)).toLocaleString('en-IN')})
                          </span>
                        </div>
                      </div>
                    </div>

                    {/* Quantity-Based Dynamic Pricing Section on Card */}
                    <div className="pt-0.5">
                      {prod.isQuantityPricingEnabled && (prod.quantityPricingSlabs?.length || 0) > 0 ? (
                        <div className="bg-emerald-50/80 rounded-xl p-2.5 border border-emerald-200/80 text-xs space-y-1.5">
                          <div className="flex items-center justify-between text-emerald-800 font-bold text-[10px] uppercase tracking-wider">
                            <span className="flex items-center gap-1">
                              <Sparkles className="w-3 h-3 text-emerald-600" />
                              Qty-Based Pricing (ON)
                            </span>
                            <span className="bg-emerald-200/80 text-emerald-800 px-1.5 py-0.5 rounded text-[9px] font-mono">
                              {prod.quantityPricingSlabs.length} Tier{prod.quantityPricingSlabs.length > 1 ? 's' : ''}
                            </span>
                          </div>
                          <div className="text-[11px] text-emerald-950 font-mono space-y-1 pt-0.5">
                            {(prod.quantityPricingSlabs as any[]).slice(0, 3).map((slab: any, idx: number) => (
                              <div key={idx} className="flex justify-between items-center bg-white/70 px-2 py-0.5 rounded border border-emerald-100">
                                <span className="text-slate-600 font-sans">
                                  {slab.minQuantity}{slab.maxQuantity ? ` - ${slab.maxQuantity}` : '+'} pcs:
                                </span>
                                <span className="font-bold text-emerald-700">₹{Number(slab.price).toLocaleString('en-IN')} / pc</span>
                              </div>
                            ))}
                            {(prod.quantityPricingSlabs as any[]).length > 3 && (
                              <div className="text-[10px] text-emerald-700 text-right italic font-sans">
                                + {prod.quantityPricingSlabs.length - 3} more volume tiers
                              </div>
                            )}
                          </div>
                        </div>
                      ) : (
                        <div className="bg-slate-50 rounded-xl px-2.5 py-1.5 border border-slate-100 flex items-center justify-between text-[10px] text-slate-400">
                          <span className="flex items-center gap-1">
                            <span className="w-1.5 h-1.5 rounded-full bg-slate-300"></span>
                            Qty-Based Pricing: Disabled
                          </span>
                          <span className="text-slate-400 font-sans">Base Tiers Apply</span>
                        </div>
                      )}
                    </div>

                    {/* Stock & Warranty */}
                    <div className="flex items-center justify-between text-xs text-slate-500 pt-1 border-t border-slate-100">
                      <span className="flex items-center gap-1.5">
                        <Boxes className="w-3.5 h-3.5 text-slate-400" />
                        <span>Stock:</span>
                        <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold font-mono ${
                          (prod.stockQuantity ?? prod.inventory?.currentStock ?? 0) <= 0
                            ? 'bg-rose-100 text-rose-800'
                            : (prod.stockQuantity ?? prod.inventory?.currentStock ?? 0) <= 10
                            ? 'bg-amber-100 text-amber-800'
                            : 'bg-emerald-50 text-emerald-700 border border-emerald-200'
                        }`}>
                          {(prod.stockQuantity ?? prod.inventory?.currentStock ?? 0) <= 0
                            ? '0 (Out of Stock)'
                            : `${prod.stockQuantity ?? prod.inventory?.currentStock ?? 0} Units`}
                        </span>
                      </span>
                      <span className="flex items-center gap-1 text-[11px] text-slate-400 font-sans">
                        <Shield className="w-3 h-3 text-slate-400" />
                        {prod.warrantyDetails ? 'Warranty Active' : '1 Yr Warranty'}
                      </span>
                    </div>
                  </div>
                </div>

                {/* Card Footer Actions */}
                <div className="p-4 bg-slate-50/60 border-t border-slate-100 flex items-center gap-2">
                  <button
                    onClick={() => openEditModal(prod)}
                    className="flex-1 py-2 bg-white hover:bg-sky-50 text-sky-700 border border-slate-200 hover:border-sky-300 font-bold rounded-xl text-xs flex items-center justify-center gap-1.5 transition-all shadow-sm"
                  >
                    <Edit2 className="w-3.5 h-3.5" />
                    <span>Edit Product</span>
                  </button>

                  <button
                    onClick={() => setDeleteConfirmId(prod.id)}
                    className="p-2 text-rose-500 hover:text-rose-700 hover:bg-rose-50 border border-slate-200 hover:border-rose-200 rounded-xl transition-all"
                    title="Delete Product"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* CREATE / EDIT PRODUCT MODAL */}
      {modalState.isOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 my-8 space-y-5">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-lg font-black text-slate-900">
                  {modalState.mode === 'create' ? 'Add New Product' : 'Edit Product'}
                </h2>
                <p className="text-xs text-slate-500">
                  Configure details, media (Image, Video, 3D View), and 4-tier buyer pricing.
                </p>
              </div>
              <button
                onClick={() => setModalState(initialModalState)}
                className="text-slate-400 hover:text-slate-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-4 text-xs">
              {/* Product Info Section */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div className="sm:col-span-2">
                  <label className="block font-bold text-slate-700 mb-1">Product Name *</label>
                  <input
                    type="text"
                    required
                    value={modalState.name}
                    onChange={(e) => setModalState({ ...modalState, name: e.target.value })}
                    placeholder="e.g. Grand Aqua PureFlow RO 15L Water Purifier"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <div className="flex items-center justify-between mb-1">
                    <label className="block font-bold text-slate-700">Category *</label>
                    <div className="flex items-center gap-1.5">
                      <button
                        type="button"
                        onClick={() =>
                          setQuickCategoryModal({
                            open: true,
                            name: '',
                            description: '',
                          })
                        }
                        className="text-xs text-sky-600 hover:text-sky-700 font-bold flex items-center gap-0.5 hover:underline"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        New Category
                      </button>
                      {modalState.categoryId && (
                        <>
                          <span className="text-slate-300">|</span>
                          <button
                            type="button"
                            onClick={() => {
                              const curr = categories.find((c: any) => c.id === modalState.categoryId);
                              if (curr) {
                                setQuickCategoryModal({
                                  open: true,
                                  id: curr.id,
                                  name: curr.name,
                                  description: curr.description || '',
                                });
                              }
                            }}
                            className="text-xs text-slate-500 hover:text-sky-600 font-bold flex items-center gap-0.5 hover:underline"
                          >
                            <Edit2 className="w-3 h-3" />
                            Edit
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                  <select
                    required
                    value={modalState.categoryId}
                    onChange={(e) => setModalState({ ...modalState, categoryId: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  >
                    <option value="">Select Category</option>
                    {categories.map((c: any) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">SKU (Auto-generated if empty)</label>
                  <input
                    type="text"
                    value={modalState.sku}
                    onChange={(e) => setModalState({ ...modalState, sku: e.target.value })}
                    placeholder="e.g. GA-RO-101"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl font-mono focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Brand</label>
                  <input
                    type="text"
                    value={modalState.brand}
                    onChange={(e) => setModalState({ ...modalState, brand: e.target.value })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 mb-1">Stock Quantity</label>
                  <input
                    type="number"
                    min="0"
                    value={modalState.stock}
                    onChange={(e) => setModalState({ ...modalState, stock: Number(e.target.value) })}
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block font-bold text-slate-700 mb-1">Short Description</label>
                  <input
                    type="text"
                    value={modalState.shortDescription}
                    onChange={(e) => setModalState({ ...modalState, shortDescription: e.target.value })}
                    placeholder="e.g. Multi-stage filtration with copper enricher and digital TDS monitor"
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>

                <div className="sm:col-span-2">
                  <label className="block font-bold text-slate-700 mb-1">Full Description / Specifications</label>
                  <textarea
                    rows={2}
                    value={modalState.fullDescription}
                    onChange={(e) => setModalState({ ...modalState, fullDescription: e.target.value })}
                    placeholder="Detailed specs, membrane capacity, purification technology..."
                    className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-sky-500"
                  />
                </div>
              </div>

              {/* MEDIA SECTION: IMAGE UPLOAD, VIDEO UPLOAD, 3D MODEL UPLOAD */}
              <div className="p-4 bg-sky-50/50 rounded-2xl border border-sky-100 space-y-3">
                <div className="flex items-center justify-between text-sky-800 font-bold">
                  <div className="flex items-center gap-2">
                    <Sparkles className="w-4 h-4 text-sky-600" />
                    <span>Product Media Upload: Image, Video & 3D Interactive File</span>
                  </div>
                  <span className="text-[11px] font-normal text-slate-500">Upload directly from your device</span>
                </div>

                {uploadError && (
                  <div className="p-2.5 bg-rose-50 border border-rose-200 rounded-xl text-xs text-rose-700 flex items-center justify-between">
                    <span>{uploadError}</span>
                    <button type="button" onClick={() => setUploadError(null)} className="text-rose-400 hover:text-rose-600">
                      <X className="w-4 h-4" />
                    </button>
                  </div>
                )}

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                  {/* 1. PRODUCT IMAGE UPLOAD */}
                  <div className="bg-white p-3 rounded-xl border border-slate-200 flex flex-col justify-between">
                    <label className="block font-bold text-slate-700 mb-1.5 flex items-center gap-1.5 text-xs">
                      <ImageIcon className="w-4 h-4 text-sky-600" />
                      <span>Product Image</span>
                    </label>

                    {modalState.imageUrl ? (
                      <div className="relative group border border-slate-200 rounded-xl overflow-hidden bg-slate-50 p-2">
                        <img
                          src={modalState.imageUrl}
                          alt="Product Preview"
                          className="w-full h-24 object-contain rounded-lg"
                        />
                        <div className="mt-2 flex items-center justify-between border-t border-slate-200 pt-1.5">
                          <button
                            type="button"
                            onClick={() => previewUploadedMedia('image')}
                            className="text-[10px] text-sky-600 hover:text-sky-800 font-bold flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" /> Preview
                          </button>
                          <button
                            type="button"
                            onClick={() => setModalState({ ...modalState, imageUrl: '' })}
                            className="text-[10px] text-rose-600 hover:underline font-bold"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ) : (
                      <label className="border-2 border-dashed border-sky-200 hover:border-sky-400 rounded-xl p-3 flex flex-col items-center justify-center cursor-pointer bg-sky-50/30 transition-all text-center">
                        <input
                          type="file"
                          accept="image/*"
                          className="hidden"
                          onChange={(e) => {
                            if (e.target.files?.[0]) handleFileUpload(e.target.files[0], 'image');
                          }}
                        />
                        {uploadingField === 'image' ? (
                          <div className="py-3 flex flex-col items-center gap-1.5 text-sky-600">
                            <Loader2 className="w-5 h-5 animate-spin" />
                            <span className="text-[11px] font-bold">Uploading Image...</span>
                          </div>
                        ) : (
                          <>
                            <Upload className="w-6 h-6 text-sky-500 mb-1" />
                            <span className="text-xs font-bold text-slate-700">Choose / Drop Image</span>
                            <span className="text-[10px] text-slate-400 mt-0.5">PNG, JPG, WebP</span>
                          </>
                        )}
                      </label>
                    )}
                  </div>

                  {/* 2. PRODUCT VIDEO UPLOAD */}
                  <div className="bg-white p-3 rounded-xl border border-slate-200 flex flex-col justify-between">
                    <label className="block font-bold text-slate-700 mb-1.5 flex items-center gap-1.5 text-xs">
                      <Video className="w-4 h-4 text-rose-600" />
                      <span>Product Video</span>
                    </label>

                    {modalState.videoUrl ? (
                      <div className="border border-slate-200 rounded-xl p-2.5 bg-slate-50 flex flex-col justify-between h-28">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-lg bg-rose-100 flex items-center justify-center text-rose-600">
                            <Video className="w-4 h-4" />
                          </div>
                          <div className="overflow-hidden">
                            <p className="text-[11px] font-bold text-slate-800 truncate">{modalState.videoUrl.split('/').pop()}</p>
                            <span className="text-[10px] text-emerald-700 font-bold flex items-center gap-1">
                              <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                              Video Uploaded
                            </span>
                          </div>
                        </div>
                        <div className="flex items-center justify-between border-t border-slate-200 pt-1.5">
                          <button
                            type="button"
                            onClick={() => previewUploadedMedia('video')}
                            className="text-[10px] text-rose-600 hover:text-rose-800 font-bold flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" /> Preview
                          </button>
                          <button
                            type="button"
                            onClick={() => setModalState({ ...modalState, videoUrl: '' })}
                            className="text-[10px] text-rose-600 hover:underline font-bold"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ) : (
                      <label className="border-2 border-dashed border-rose-200 hover:border-rose-400 rounded-xl p-3 flex flex-col items-center justify-center cursor-pointer bg-rose-50/30 transition-all text-center">
                        <input
                          type="file"
                          accept="video/*"
                          className="hidden"
                          onChange={(e) => {
                            if (e.target.files?.[0]) handleFileUpload(e.target.files[0], 'video');
                          }}
                        />
                        {uploadingField === 'video' ? (
                          <div className="py-3 flex flex-col items-center gap-1.5 text-rose-600">
                            <Loader2 className="w-5 h-5 animate-spin" />
                            <span className="text-[11px] font-bold">Uploading Video...</span>
                          </div>
                        ) : (
                          <>
                            <Upload className="w-6 h-6 text-rose-500 mb-1" />
                            <span className="text-xs font-bold text-slate-700">Choose / Drop Video</span>
                            <span className="text-[10px] text-slate-400 mt-0.5">MP4, WebM (up to 100MB)</span>
                          </>
                        )}
                      </label>
                    )}
                  </div>

                  {/* 3. PRODUCT 3D VIEW UPLOAD */}
                  <div className="bg-white p-3 rounded-xl border border-slate-200 flex flex-col justify-between">
                    <label className="block font-bold text-slate-700 mb-1.5 flex items-center gap-1.5 text-xs">
                      <Box className="w-4 h-4 text-purple-600" />
                      <span>Product 3D Model</span>
                    </label>

                    {modalState.model3dUrl ? (
                      <div className="border border-slate-200 rounded-xl p-2.5 bg-slate-50 flex flex-col justify-between h-28">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center text-purple-600">
                            <Box className="w-4 h-4" />
                          </div>
                          <div className="overflow-hidden">
                            <p className="text-[11px] font-bold text-slate-800 truncate">{modalState.model3dUrl.split('/').pop()}</p>
                            <span className="text-[10px] text-emerald-700 font-bold flex items-center gap-1">
                              <CheckCircle2 className="w-3 h-3 text-emerald-600" />
                              3D File Uploaded
                            </span>
                          </div>
                        </div>
                        <div className="flex items-center justify-between border-t border-slate-200 pt-1.5">
                          <button
                            type="button"
                            onClick={() => previewUploadedMedia('3d')}
                            className="text-[10px] text-purple-600 hover:text-purple-800 font-bold flex items-center gap-1"
                          >
                            <Eye className="w-3 h-3" /> Preview 3D
                          </button>
                          <button
                            type="button"
                            onClick={() => setModalState({ ...modalState, model3dUrl: '' })}
                            className="text-[10px] text-rose-600 hover:underline font-bold"
                          >
                            Remove
                          </button>
                        </div>
                      </div>
                    ) : (
                      <label className="border-2 border-dashed border-purple-200 hover:border-purple-400 rounded-xl p-3 flex flex-col items-center justify-center cursor-pointer bg-purple-50/30 transition-all text-center">
                        <input
                          type="file"
                          accept=".glb,.gltf,.obj,.stl"
                          className="hidden"
                          onChange={(e) => {
                            if (e.target.files?.[0]) handleFileUpload(e.target.files[0], '3d');
                          }}
                        />
                        {uploadingField === '3d' ? (
                          <div className="py-3 flex flex-col items-center gap-1.5 text-purple-600">
                            <Loader2 className="w-5 h-5 animate-spin" />
                            <span className="text-[11px] font-bold">Uploading 3D Model...</span>
                          </div>
                        ) : (
                          <>
                            <Upload className="w-6 h-6 text-purple-500 mb-1" />
                            <span className="text-xs font-bold text-slate-700">Choose / Drop 3D File</span>
                            <span className="text-[10px] text-slate-400 mt-0.5">.GLB, .GLTF, .OBJ</span>
                          </>
                        )}
                      </label>
                    )}
                  </div>
                </div>
              </div>

              {/* 4-TIER PRICING SECTION */}
              <div className="p-4 bg-slate-50 rounded-2xl border border-slate-200 space-y-3">
                <div className="font-bold text-slate-800 flex items-center justify-between">
                  <span>Independent 4-Tier Pricing (Excl. 18% GST)</span>
                  <span className="text-[10px] text-slate-400 font-normal">All prices in Indian Rupees (₹)</span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div className="sm:col-span-2 p-2.5 bg-amber-50 rounded-xl border border-amber-200">
                    <label className="block font-bold text-amber-900 text-xs mb-1 flex items-center justify-between">
                      <span>Purchase / Cost Price (₹)</span>
                      <span className="text-[10px] font-semibold text-amber-800 bg-amber-200/80 px-2 py-0.5 rounded-full">Super Admin Confidential</span>
                    </label>
                    <input
                      type="number"
                      min="0"
                      value={modalState.purchasePrice}
                      onChange={(e) => setModalState({ ...modalState, purchasePrice: Number(e.target.value) })}
                      placeholder="Enter purchase cost"
                      className="w-full px-3 py-2 bg-white border border-amber-300 rounded-lg font-mono font-bold text-amber-900 focus:outline-none focus:ring-2 focus:ring-amber-500"
                    />
                    <p className="text-[10px] text-amber-700 mt-1">Confidential cost price. Used to calculate real-time net profit and margins on quotations and orders.</p>
                  </div>

                  <div>
                    <label className="block font-bold text-sky-800 mb-1">1. Distributor Price (₹)</label>
                    <input
                      type="number"
                      min="0"
                      required
                      value={modalState.distributorPrice}
                      onChange={(e) => setModalState({ ...modalState, distributorPrice: Number(e.target.value) })}
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-sky-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-cyan-800 mb-1">2. Wholesaler Price (₹)</label>
                    <input
                      type="number"
                      min="0"
                      required
                      value={modalState.wholesalerPrice}
                      onChange={(e) => setModalState({ ...modalState, wholesalerPrice: Number(e.target.value) })}
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-cyan-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-teal-800 mb-1">3. Dealer / Retailer Price (₹)</label>
                    <input
                      type="number"
                      min="0"
                      required
                      value={modalState.dealerPrice}
                      onChange={(e) => setModalState({ ...modalState, dealerPrice: Number(e.target.value) })}
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-teal-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>

                  <div>
                    <label className="block font-bold text-slate-900 mb-1">4. Direct Customer Price (₹)</label>
                    <input
                      type="number"
                      min="0"
                      required
                      value={modalState.customerPrice}
                      onChange={(e) => setModalState({ ...modalState, customerPrice: Number(e.target.value) })}
                      className="w-full px-3 py-2 bg-white border border-slate-200 rounded-xl font-mono font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-sky-500"
                    />
                  </div>
                </div>
              </div>

              {/* QUANTITY-BASED DYNAMIC PRICING (ON/OFF TOGGLE & CUSTOMIZABLE SLABS) */}
              <div className="p-4 bg-emerald-50/50 rounded-2xl border border-emerald-200 space-y-3">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-emerald-100 pb-3">
                  <div>
                    <div className="flex items-center gap-2">
                      <Layers className="w-4 h-4 text-emerald-600" />
                      <span className="font-bold text-slate-900 text-sm">Volume / Quantity-Based Pricing</span>
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold ${modalState.isQuantityPricingEnabled ? 'bg-emerald-100 text-emerald-800 border border-emerald-300' : 'bg-slate-200 text-slate-600'}`}>
                        {modalState.isQuantityPricingEnabled ? 'ON (Active)' : 'OFF (Disabled)'}
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-500 mt-0.5">
                      Turn ON to offer customized unit prices for buyers ordering in wholesale/bulk quantities.
                    </p>
                  </div>

                  {/* Turn ON / Turn OFF Switch */}
                  <label className="relative inline-flex items-center cursor-pointer select-none">
                    <input
                      type="checkbox"
                      checked={modalState.isQuantityPricingEnabled}
                      onChange={(e) => setModalState({ ...modalState, isQuantityPricingEnabled: e.target.checked })}
                      className="sr-only peer"
                    />
                    <div className="w-11 h-6 bg-slate-300 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-slate-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-600"></div>
                  </label>
                </div>

                {modalState.isQuantityPricingEnabled ? (
                  <div className="space-y-3 pt-1">
                    {modalState.quantityPricingSlabs.length === 0 ? (
                      <div className="p-4 bg-white rounded-xl border border-dashed border-emerald-300 text-center text-xs text-slate-500 space-y-1">
                        <p className="font-semibold text-slate-700">No volume slabs configured yet.</p>
                        <p className="text-[11px] text-slate-400">Click &quot;+ Add Quantity Tier&quot; below to define your first custom quantity and price slab.</p>
                      </div>
                    ) : (
                      <div className="space-y-2">
                        <div className="grid grid-cols-12 gap-2 text-[11px] font-bold text-slate-600 px-1">
                          <span className="col-span-4">Min Quantity</span>
                          <span className="col-span-4">Max Quantity (Optional)</span>
                          <span className="col-span-3">Unit Price (₹)</span>
                          <span className="col-span-1 text-center">Action</span>
                        </div>

                        {modalState.quantityPricingSlabs.map((slab, idx) => (
                          <div key={idx} className="grid grid-cols-12 gap-2 items-center bg-white p-2.5 rounded-xl border border-slate-200 shadow-sm">
                            <div className="col-span-4">
                              <input
                                type="number"
                                min="1"
                                placeholder="Min Qty"
                                value={slab.minQuantity}
                                onChange={(e) => {
                                  const updated = [...modalState.quantityPricingSlabs];
                                  updated[idx] = { ...updated[idx], minQuantity: Math.max(1, Number(e.target.value)) };
                                  setModalState({ ...modalState, quantityPricingSlabs: updated });
                                }}
                                className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono font-bold focus:outline-none focus:ring-2 focus:ring-emerald-500"
                              />
                            </div>

                            <div className="col-span-4">
                              <input
                                type="number"
                                min={slab.minQuantity}
                                placeholder="and above"
                                value={slab.maxQuantity ?? ''}
                                onChange={(e) => {
                                  const updated = [...modalState.quantityPricingSlabs];
                                  const val = e.target.value ? Number(e.target.value) : null;
                                  updated[idx] = { ...updated[idx], maxQuantity: val };
                                  setModalState({ ...modalState, quantityPricingSlabs: updated });
                                }}
                                className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono focus:outline-none focus:ring-2 focus:ring-emerald-500"
                              />
                            </div>

                            <div className="col-span-3">
                              <input
                                type="number"
                                min="0"
                                placeholder="Price (₹)"
                                value={slab.price}
                                onChange={(e) => {
                                  const updated = [...modalState.quantityPricingSlabs];
                                  updated[idx] = { ...updated[idx], price: Number(e.target.value) };
                                  setModalState({ ...modalState, quantityPricingSlabs: updated });
                                }}
                                className="w-full px-2.5 py-1.5 bg-slate-50 border border-slate-200 rounded-lg text-xs font-mono font-bold text-emerald-800 focus:outline-none focus:ring-2 focus:ring-emerald-500"
                              />
                            </div>

                            <div className="col-span-1 text-center">
                              <button
                                type="button"
                                title="Remove slab"
                                onClick={() => {
                                  const updated = modalState.quantityPricingSlabs.filter((_, i) => i !== idx);
                                  setModalState({ ...modalState, quantityPricingSlabs: updated });
                                }}
                                className="p-1.5 text-slate-400 hover:text-rose-600 rounded-lg hover:bg-rose-50 transition-colors"
                              >
                                <Trash2 className="w-3.5 h-3.5" />
                              </button>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}

                    <div className="flex justify-between items-center pt-1">
                      <span className="text-[11px] text-slate-500 font-mono">
                        {modalState.quantityPricingSlabs.length} customized slab(s)
                      </span>
                      <button
                        type="button"
                        onClick={() => {
                          const last = modalState.quantityPricingSlabs[modalState.quantityPricingSlabs.length - 1];
                          const nextMin = last?.maxQuantity ? last.maxQuantity + 1 : last?.minQuantity ? last.minQuantity + 10 : 10;
                          setModalState({
                            ...modalState,
                            quantityPricingSlabs: [
                              ...modalState.quantityPricingSlabs,
                              { minQuantity: nextMin, maxQuantity: null, price: modalState.customerPrice ? Math.round(modalState.customerPrice * 0.9) : 0 },
                            ],
                          });
                        }}
                        className="px-3 py-1.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold rounded-xl shadow-sm flex items-center gap-1.5 transition-all"
                      >
                        <Plus className="w-3.5 h-3.5" />
                        <span>Add Quantity Tier</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className="p-3 bg-white/70 rounded-xl border border-slate-200 text-xs text-slate-500 flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-slate-400"></span>
                    <span>Quantity-based pricing is currently turned <strong>OFF</strong>. Standard 4-Tier prices apply to all buyer orders regardless of order quantity.</span>
                  </div>
                )}
              </div>

              {/* Footer Buttons */}
              <div className="flex items-center justify-end gap-3 pt-3 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setModalState(initialModalState)}
                  className="px-4 py-2 font-bold text-slate-600 hover:bg-slate-100 rounded-xl transition-all"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={createProductMutation.isPending || updateProductMutation.isPending}
                  className="px-5 py-2.5 bg-sky-600 hover:bg-sky-700 text-white font-bold rounded-xl shadow-md disabled:opacity-50 transition-all"
                >
                  {createProductMutation.isPending || updateProductMutation.isPending
                    ? 'Saving...'
                    : modalState.mode === 'create'
                    ? 'Create Product'
                    : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* MEDIA PREVIEW MODAL (IMAGE, VIDEO, 3D MODEL) */}
      {viewingMediaProduct && (
        <div className="fixed inset-0 z-50 bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-base font-bold text-slate-900 flex items-center gap-2">
                  <Sparkles className="w-4 h-4 text-sky-600" />
                  Media & 3D Interactive View
                </h2>
                <p className="text-xs text-slate-500 font-mono">
                  {viewingMediaProduct.sku} • {viewingMediaProduct.name}
                </p>
              </div>
              <button onClick={() => setViewingMediaProduct(null)} className="text-slate-400 hover:text-slate-600">
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Media Tabs */}
            <div className="flex items-center gap-2 border-b border-slate-100 pb-2">
              <button
                onClick={() => setMediaActiveTab('image')}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
                  mediaActiveTab === 'image'
                    ? 'bg-sky-600 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                <ImageIcon className="w-3.5 h-3.5" />
                <span>Product Image</span>
              </button>

              <button
                onClick={() => setMediaActiveTab('video')}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
                  mediaActiveTab === 'video'
                    ? 'bg-rose-600 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                <Video className="w-3.5 h-3.5" />
                <span>Product Video</span>
              </button>

              <button
                onClick={() => setMediaActiveTab('3d')}
                className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
                  mediaActiveTab === '3d'
                    ? 'bg-purple-600 text-white shadow-sm'
                    : 'text-slate-600 hover:bg-slate-100'
                }`}
              >
                <Box className="w-3.5 h-3.5" />
                <span>3D Interactive Model</span>
              </button>
            </div>

            {/* Media Content */}
            <div className="h-80 bg-slate-900 rounded-xl overflow-hidden flex items-center justify-center relative">
              {mediaActiveTab === 'image' && (
                (() => {
                  const img = viewingMediaProduct.media?.find((m: any) => m.mediaType === 'IMAGE');
                  return img?.url ? (
                    <img src={img.url} alt={viewingMediaProduct.name} className="w-full h-full object-contain" />
                  ) : (
                    <div className="text-center text-slate-400">
                      <ImageIcon className="w-12 h-12 mx-auto mb-2 opacity-50" />
                      <p className="text-xs">No image uploaded for this product.</p>
                    </div>
                  );
                })()
              )}

              {mediaActiveTab === 'video' && (
                (() => {
                  const vid = viewingMediaProduct.media?.find((m: any) => m.mediaType === 'VIDEO');
                  if (!vid?.url) {
                    return (
                      <div className="text-center text-slate-400">
                        <Video className="w-12 h-12 mx-auto mb-2 opacity-50" />
                        <p className="text-xs">No video URL registered for this product.</p>
                      </div>
                    );
                  }
                  // Check if YouTube
                  if (vid.url.includes('youtube.com') || vid.url.includes('youtu.be')) {
                    let embedUrl = vid.url;
                    if (vid.url.includes('watch?v=')) {
                      embedUrl = vid.url.replace('watch?v=', 'embed/');
                    } else if (vid.url.includes('youtu.be/')) {
                      embedUrl = vid.url.replace('youtu.be/', 'www.youtube.com/embed/');
                    }
                    return (
                      <iframe
                        src={embedUrl}
                        title={viewingMediaProduct.name}
                        className="w-full h-full border-0"
                        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                        allowFullScreen
                      />
                    );
                  }
                  return (
                    <video controls src={vid.url} className="w-full h-full object-contain">
                      Your browser does not support HTML5 video.
                    </video>
                  );
                })()
              )}

              {mediaActiveTab === '3d' && (
                (() => {
                  const m3d = viewingMediaProduct.media?.find((m: any) => m.mediaType === '3D_MODEL');
                  if (!m3d?.url) {
                    return (
                      <div className="text-center text-slate-400">
                        <Box className="w-12 h-12 mx-auto mb-2 opacity-50 text-purple-400" />
                        <p className="text-xs">No 3D model (.glb/.gltf) URL registered for this product.</p>
                        <p className="text-[10px] text-slate-500 mt-1">
                          You can edit this product and paste any GLB/GLTF model URL to enable full 3D interactive viewing.
                        </p>
                      </div>
                    );
                  }
                  return (
                    // @ts-ignore
                    <model-viewer
                      src={m3d.url}
                      alt={viewingMediaProduct.name}
                      auto-rotate
                      camera-controls
                      ar
                      style={{ width: '100%', height: '100%' }}
                    />
                  );
                })()
              )}
            </div>

            <div className="flex items-center justify-between text-xs text-slate-500 pt-2 border-t border-slate-100">
              <span className="font-mono">
                Category: <strong>{viewingMediaProduct.category?.name || 'General'}</strong>
              </span>
              <button
                onClick={() => setViewingMediaProduct(null)}
                className="px-4 py-1.5 bg-slate-100 hover:bg-slate-200 text-slate-800 font-bold rounded-xl"
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
              <h3 className="font-bold text-slate-900 text-base">Delete Product?</h3>
              <p className="text-xs text-slate-500 mt-1">
                Are you sure you want to permanently delete this product and its 4-tier pricing, media, and inventory records? This action cannot be undone.
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
                disabled={deleteProductMutation.isPending}
                onClick={() => deleteProductMutation.mutate(deleteConfirmId)}
                className="flex-1 py-2 bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold rounded-xl shadow-md disabled:opacity-50"
              >
                {deleteProductMutation.isPending ? 'Deleting...' : 'Confirm Delete'}
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Quick Add / Edit Category Nested Modal */}
      {quickCategoryModal && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl max-w-sm w-full p-5 shadow-2xl border border-slate-100 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-2">
              <h3 className="font-bold text-slate-900 text-sm flex items-center gap-1.5">
                <Layers className="w-4 h-4 text-sky-600" />
                {quickCategoryModal.id ? 'Edit Category' : 'Add New Category'}
              </h3>
              <button
                type="button"
                onClick={() => setQuickCategoryModal(null)}
                className="text-slate-400 hover:text-slate-600 p-1 hover:bg-slate-100 rounded-lg"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="space-y-3">
              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Category Name *</label>
                <input
                  type="text"
                  required
                  value={quickCategoryModal.name}
                  onChange={(e) => setQuickCategoryModal({ ...quickCategoryModal, name: e.target.value })}
                  placeholder="e.g. Commercial RO, Water Softeners"
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs font-bold text-slate-900 focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 mb-1">Description (Optional)</label>
                <textarea
                  rows={2}
                  value={quickCategoryModal.description}
                  onChange={(e) => setQuickCategoryModal({ ...quickCategoryModal, description: e.target.value })}
                  placeholder="Brief description of product classification..."
                  className="w-full px-3 py-2 bg-slate-50 border border-slate-200 rounded-xl text-xs text-slate-800 focus:outline-none focus:ring-2 focus:ring-sky-500"
                />
              </div>
            </div>

            <div className="flex items-center justify-end gap-2 pt-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setQuickCategoryModal(null)}
                className="px-3 py-1.5 text-xs font-bold text-slate-600 hover:bg-slate-100 rounded-lg"
              >
                Cancel
              </button>
              <button
                type="button"
                disabled={!quickCategoryModal.name.trim() || saveQuickCategoryMutation.isPending}
                onClick={() =>
                  saveQuickCategoryMutation.mutate({
                    id: quickCategoryModal.id,
                    name: quickCategoryModal.name.trim(),
                    description: quickCategoryModal.description.trim() || undefined,
                  })
                }
                className="px-4 py-2 bg-sky-600 hover:bg-sky-700 text-white text-xs font-bold rounded-lg shadow-sm disabled:opacity-50"
              >
                {saveQuickCategoryMutation.isPending
                  ? 'Saving...'
                  : quickCategoryModal.id
                  ? 'Update Category'
                  : 'Save Category'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
