import { Button } from "@/components/ui/button"
import { ArrowRight, BookOpen } from "lucide-react"
import Link from "next/link"

export function CallToAction() {
  return (
    <section className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-4xl mx-auto text-center">
        <div className="bg-gradient-to-r from-teal-600/20 to-cyan-600/20 backdrop-blur-sm border border-teal-500/30 rounded-2xl p-12">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-6">Ready to Start Cross-Chain Lending?</h2>
          <p className="text-xl text-gray-300 mb-8 max-w-2xl mx-auto">
            Join the future of DeFi with institutional-grade security and seamless cross-chain operations.
          </p>

          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link href="/dashboard">
              <Button
                size="lg"
                className="bg-gradient-to-r from-teal-500 to-cyan-500 hover:from-teal-600 hover:to-cyan-600 text-white font-semibold text-lg px-8 py-4"
              >
                Start Lending
                <ArrowRight className="ml-2 w-5 h-5" />
              </Button>
            </Link>
            <Button
              variant="outline"
              size="lg"
              className="border-teal-500 text-teal-400 hover:bg-teal-500/10 text-lg px-8 py-4"
            >
              <BookOpen className="mr-2 w-5 h-5" />
              Learn More
            </Button>
          </div>
        </div>
      </div>
    </section>
  )
}
