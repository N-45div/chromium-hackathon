import { WalletGuard } from "@/components/wallet-guard"
import { DepositForm } from "@/components/deposit-form"
import { AdvancedDepositForm } from "@/components/advanced-deposit-form"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export default function DepositPage() {
  return (
    <WalletGuard>
      <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900 p-6">
        <div className="max-w-4xl mx-auto">
          <h1 className="text-3xl font-bold text-white mb-8">Deposit Collateral</h1>
          <Tabs defaultValue="simple" className="w-full">
            <TabsList className="grid w-full grid-cols-2 bg-slate-800 border-slate-700">
              <TabsTrigger value="simple" className="text-white data-[state=active]:bg-teal-600">
                Simple Deposit
              </TabsTrigger>
              <TabsTrigger value="advanced" className="text-white data-[state=active]:bg-teal-600">
                Cross-Chain Deposit
              </TabsTrigger>
            </TabsList>
            <TabsContent value="simple" className="mt-6">
              <DepositForm />
            </TabsContent>
            <TabsContent value="advanced" className="mt-6">
              <AdvancedDepositForm />
            </TabsContent>
          </Tabs>
        </div>
      </div>
    </WalletGuard>
  )
}
