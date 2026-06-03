import { redirect as nextRedirect } from 'next/navigation'
import { addExternalBasePath } from '@/utils/var'

export {
  useParams,
  usePathname,
  useRouter,
  useSearchParams,
  useSelectedLayoutSegment,
  useSelectedLayoutSegments,
} from 'next/navigation'
export type { ReadonlyURLSearchParams } from 'next/navigation'

export function redirect(...args: Parameters<typeof nextRedirect>): ReturnType<typeof nextRedirect> {
  const [url, type] = args
  return nextRedirect(typeof url === 'string' ? addExternalBasePath(url) : url, type)
}
