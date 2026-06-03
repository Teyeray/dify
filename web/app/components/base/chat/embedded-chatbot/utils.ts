export const isDefaultBrand = () => {
  return document.referrer.includes('dify.ai')
}

export const isDify = isDefaultBrand
