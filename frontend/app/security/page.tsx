import { WalletGuard } from "@/components/wallet-guard"
import { MultiSigSetup } from "@/components/multi-sig-setup"
import { PrivacyControls } from "@/components/privacy-controls"
import { MonitoringAlerts } from "@/components/monitoring-alerts"

export default function SecurityPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-6xl mx-auto space-y-6">
          <h1 className="text-3xl font-bold text-white mb-8">Security Settings</h1>
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <MultiSigSetup />
            <PrivacyControls />
          </div>
          <MonitoringAlerts />
        </div>
      </div>
    </WalletGuard>
  )
}
