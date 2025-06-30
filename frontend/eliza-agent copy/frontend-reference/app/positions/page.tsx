import { WalletGuard } from "@/components/wallet-guard"
import { ActivePositions } from "@/components/active-positions"
import { WithdrawCollateral } from "@/components/withdraw-collateral"
import { RepayLoans } from "@/components/repay-loans"

export default function PositionsPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-7xl mx-auto space-y-6">
          <h1 className="text-3xl font-bold text-white mb-8">Manage Positions</h1>
          <ActivePositions />
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <WithdrawCollateral />
            <RepayLoans />
          </div>
        </div>
      </div>
    </WalletGuard>
  )
}
