import { WalletGuard } from "@/components/wallet-guard"
import { AvailableBorrowing } from "@/components/available-borrowing"
import { BorrowInterface } from "@/components/borrow-interface"

export default function BorrowPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-6xl mx-auto space-y-6">
          <h1 className="text-3xl font-bold text-white mb-8">Borrow Tokens</h1>
          <AvailableBorrowing />
          <BorrowInterface />
        </div>
      </div>
    </WalletGuard>
  )
}
