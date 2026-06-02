import { useMemo } from 'react'
import {
  redirect as nextRedirect,
  useRouter as useNextRouter,
} from 'next/navigation'
import { addExternalBasePath, externalBasePath, isLocalAbsolutePath } from '@/utils/var'

export {
  useParams,
  usePathname,
  useSearchParams,
  useSelectedLayoutSegment,
  useSelectedLayoutSegments,
} from 'next/navigation'
export type { ReadonlyURLSearchParams } from 'next/navigation'

export function redirect(...args: Parameters<typeof nextRedirect>): ReturnType<typeof nextRedirect> {
  const [url, type] = args
  return nextRedirect(typeof url === 'string' ? addExternalBasePath(url) : url, type)
}

export function useRouter() {
  const router = useNextRouter()

  return useMemo(() => {
    if (!externalBasePath)
      return router

    return {
      ...router,
      push: (href: string, options?: Parameters<typeof router.push>[1]) => {
        if (isLocalAbsolutePath(href)) {
          window.location.assign(addExternalBasePath(href))
          return
        }

        router.push(href, options)
      },
      replace: (href: string, options?: Parameters<typeof router.replace>[1]) => {
        if (isLocalAbsolutePath(href)) {
          window.location.replace(addExternalBasePath(href))
          return
        }

        router.replace(href, options)
      },
    }
  }, [router])
}
