"use client"

import { Card, CardContent } from "@/components/ui/card"
import { TrendingUp, Users, Network, DollarSign } from "lucide-react"
import { useEffect, useState } from "react"

const stats = [
  {
    icon: DollarSign,
    label: "Total Value Locked",
    value: 0,
    target: 2400000000,
    prefix: "$",
    suffix: "B",
  },
  {
    icon: TrendingUp,
    label: "Active Loans",
    value: 0,
    target: 15420,
    prefix: "",
    suffix: "",
  },
  {
    icon: Network,
    label: "Supported Chains",
    value: 0,
    target: 8,
    prefix: "",
    suffix: "",
  },
  {
    icon: Users,
    label: "Total Users",
    value: 0,
    target: 89500,
    prefix: "",
    suffix: "+",
  },
]

export function StatsSection() {
  const [animatedStats, setAnimatedStats] = useState(stats)

  useEffect(() => {
    const animateStats = () => {
      stats.forEach((stat, index) => {
        let current = 0
        const increment = stat.target / 100
        const timer = setInterval(() => {
          current += increment
          if (current >= stat.target) {
            current = stat.target
            clearInterval(timer)
          }
          setAnimatedStats((prev) => prev.map((s, i) => (i === index ? { ...s, value: Math.floor(current) } : s)))
        }, 20)
      })
    }

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          animateStats()
          observer.disconnect()
        }
      },
      { threshold: 0.5 },
    )

    const element = document.getElementById("stats-section")
    if (element) observer.observe(element)

    return () => observer.disconnect()
  }, [])

  const formatValue = (stat: (typeof stats)[0]) => {
    const { value, prefix, suffix, target } = stat
    if (target >= 1000000000) {
      return `${prefix}${(value / 1000000000).toFixed(1)}${suffix}`
    }
    if (target >= 1000000) {
      return `${prefix}${(value / 1000000).toFixed(1)}M${suffix}`
    }
    if (target >= 1000) {
      return `${prefix}${(value / 1000).toFixed(1)}K${suffix}`
    }
    return `${prefix}${value}${suffix}`
  }

  return (
    <section id="stats-section" className="py-24 px-4 sm:px-6 lg:px-8">
      <div className="max-w-7xl mx-auto">
        <div className="text-center mb-16">
          <h2 className="text-3xl md:text-4xl font-bold text-white mb-4">Trusted by DeFi Leaders</h2>
          <p className="text-xl text-gray-300">Join thousands of users leveraging cross-chain lending</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          {animatedStats.map((stat, index) => (
            <Card key={index} className="bg-slate-800/50 backdrop-blur-sm border-slate-700 text-center">
              <CardContent className="p-6">
                <div className="w-12 h-12 bg-teal-600/20 rounded-lg flex items-center justify-center mx-auto mb-4">
                  <stat.icon className="w-6 h-6 text-teal-400" />
                </div>
                <div className="text-3xl font-bold text-white mb-2">{formatValue(stat)}</div>
                <div className="text-gray-300">{stat.label}</div>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
