import type { AnchorHTMLAttributes } from 'react'
import type { LinkProps as NextLinkProps } from 'next/link'
import { createElement } from 'react'
import NextLink from 'next/link'
import { addExternalBasePath, externalBasePath, isLocalAbsolutePath } from '@/utils/var'

type Props = NextLinkProps & Omit<AnchorHTMLAttributes<HTMLAnchorElement>, keyof NextLinkProps>

export default function Link(props: Props) {
  const { href } = props

  if (externalBasePath && typeof href === 'string' && isLocalAbsolutePath(href)) {
    const {
      as: _as,
      href: _href,
      locale: _locale,
      prefetch: _prefetch,
      replace: _replace,
      scroll: _scroll,
      shallow: _shallow,
      ...anchorProps
    } = props

    return createElement('a', {
      ...anchorProps,
      href: addExternalBasePath(href),
    })
  }

  return createElement(NextLink, props)
}
