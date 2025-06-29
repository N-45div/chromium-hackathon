import { CCIPTransferForm } from "@/components/ccip-transfer-form"

export default function CCIPTransferPage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-3xl font-bold text-white mb-8">CCIP Cross-Chain Transfer</h1>
        <CCIPTransferForm />
      </div>
    </div>
  )
}
