import { Card, CardContent } from "@/components/ui/card"
import { Shield, Zap, Globe, Lock } from "lucide-react"

const features = [
  {
    icon: Zap,
    title: "Cross-Chain Lending",
    description: "Deposit ETH on Ethereum, borrow USDC on BNB Chain. Seamless cross-chain operations.",
    chains: ["Ethereum", "BNB Chain", "Avalanche"],
  },
  {
    icon: Shield,
    title: "Institutional Security",
    description: "Multi-signature wallets, AI monitoring, and comprehensive insurance protection.",
    features: ["Multi-sig", "AI Monitoring", "Insurance"],
  },
  {
    icon: Lock,
    title: "Privacy Protection",
    description: "Zero-knowledge proofs ensure your financial activities remain confidential.",
    features: ["Zero-Knowledge", "Confidential", "Anonymous"],
  },
  {
    icon: Globe,
    title: "Multi-Chain Support",
    description: "Access liquidity across multiple blockchain networks with unified interface.",
    features: ["ETH Collateral", "BNB Collateral", "USDC Borrowing"],
  },
]

export function FeaturesOverview() {
  return (
    <section className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">Powerful Cross-Chain Features</h2>
          <p className="text-xl text-gray-300 max-w-3xl mx-auto">
            Experience the next generation of DeFi with our comprehensive cross-chain lending protocol
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {features.map((feature, index) => (
            <Card
              key={index}
              className="bg-slate-800/50 backdrop-blur-sm border-slate-700 hover:border-teal-500/50 transition-all duration-300 hover:transform hover:scale-105"
            >
              <CardContent className="p-6">
                <div className="w-12 h-12 bg-teal-600/20 rounded-lg flex items-center justify-center mb-4">
                  <feature.icon className="w-6 h-6 text-teal-400" />
                </div>
                <h3 className="text-xl font-semibold text-white mb-3">{feature.title}</h3>
                <p className="text-gray-300 mb-4">{feature.description}</p>
                <div className="flex flex-wrap gap-2">
                  {(feature.chains || feature.features)?.map((item, idx) => (
                    <span key={idx} className="px-2 py-1 bg-teal-600/20 text-teal-300 text-xs rounded-full">
                      {item}
                    </span>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
