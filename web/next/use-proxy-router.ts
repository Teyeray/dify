'use client'
import { useMemo } from 'react'
import { useRouter as nextUseRouter } from 'next/navigation'
import { addExternalBasePath, externalBasePath, isLocalAbsolutePath } from '@/utils/var'

/**
 * Drop-in replacement for useRouter() in code-server / proxy environments.
 * When NEXT_PUBLIC_EXTERNAL_BASE_PATH is set, push() and replace() use
 * window.location so the proxy prefix is preserved in the browser URL.
 *
 * Import from '@/next/use-proxy-router' instead of '@/next/navigation'
 * in components that call router.push('/absolute-path').
 *
 * In non-proxy environments this is identical to the plain useRouter().
 */
export function useRouter() {
  const router = nextUseRouter()
  return useMemo(() => {
    if (!externalBasePath)
      return router

    return {
      ...router,
      push(href: string, options?: Parameters<typeof router.push>[1]) {
        if (isLocalAbsolutePath(href))
          window.location.assign(addExternalBasePath(href))
        else
          router.push(href, options)
      },
      replace(href: string, options?: Parameters<typeof router.replace>[1]) {
        if (isLocalAbsolutePath(href))
          window.location.replace(addExternalBasePath(href))
        else
          router.replace(href, options)
      },
    }
  }, [router])
}
