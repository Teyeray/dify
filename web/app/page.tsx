'use client'

import { useEffect } from 'react'
import { useRouter } from '@/next/use-proxy-router'

type HomePageProps = {
  searchParams: Promise<Record<string, string | string[] | undefined>>
}

const Home = ({ searchParams }: HomePageProps) => {
  const router = useRouter()

  useEffect(() => {
    let cancelled = false
    void searchParams.then((resolved) => {
      if (cancelled) {
        return
      }
      const urlSearchParams = new URLSearchParams()
      Object.entries(resolved).forEach(([key, value]) => {
        if (value === undefined)
          return
        if (Array.isArray(value)) {
          value.forEach(item => urlSearchParams.append(key, item))
          return
        }
        urlSearchParams.set(key, value)
      })
      const queryString = urlSearchParams.toString()
      router.replace(queryString ? `/apps?${queryString}` : '/apps')
    })
    return () => {
      cancelled = true
    }
  }, [router, searchParams])

  return null
}

export default Home
