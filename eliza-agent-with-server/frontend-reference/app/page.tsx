import { Hero } from "@/components/hero"
import { FeaturesOverview } from "@/components/features-overview"
import { StatsSection } from "@/components/stats-section"
import { CallToAction } from "@/components/call-to-action"

export default function HomePage() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-teal-900">
      <Hero />
      <FeaturesOverview />
      <StatsSection />
      <CallToAction />
    </div>
  )
}
