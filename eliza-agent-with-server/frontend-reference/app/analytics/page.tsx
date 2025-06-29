import { WalletGuard } from "@/components/wallet-guard"
import { MarketOverview } from "@/components/market-overview"
import { PersonalAnalytics } from "@/components/personal-analytics"
import { RiskManagement } from "@/components/risk-management"

export default function AnalyticsPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-7xl mx-auto space-y-6">
          <h1 className="text-3xl font-bold text-white mb-8">Analytics</h1>
          <MarketOverview />
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <PersonalAnalytics />
            <RiskManagement />
          </div>
        </div>
      </div>
    </WalletGuard>
  )
}
