import { WalletGuard } from "@/components/wallet-guard"
import { DepositForm } from "@/components/deposit-form"
import { AdvancedDepositForm } from "@/components/advanced-deposit-form"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export default function DepositPage() {
  return (
    <WalletGuard>
      <div className="2xl:h-[92.9vh] h-full bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-3xl text-center font-bold text-white mb-8">Deposit Collateral</h1>

              <DepositForm />

        </div>
      </div>
    </WalletGuard>
  )
}
