import { WalletGuard } from "@/components/wallet-guard"
import { PortfolioOverview } from "@/components/portfolio-overview"
import { SourceChainSection } from "@/components/source-chain-section"
import { TargetChainSection } from "@/components/target-chain-section"
import { CrossChainOpportunities } from "@/components/cross-chain-opportunities"

export default function DashboardPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-7xl mx-auto space-y-6">
          <h1 className="text-3xl font-bold text-white mb-8">Dashboard</h1>
          <PortfolioOverview />
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <SourceChainSection />
            <TargetChainSection />
          </div>
          <CrossChainOpportunities />
        </div>
      </div>
    </WalletGuard>
  )
}
