import { target, targetable } from '@github/catalyst/lib/targetable'

export default targetable(class extends HTMLElement {
  static [target.static] = ['placeholder', 'error', 'retryButton']

  connectedCallback () {
    this.image = this.querySelector('img')

    this.image.addEventListener('load', this.onLoad)
    this.image.addEventListener('error', this.onError)

    this.retryButton?.addEventListener('click', this.retry)

    if (this.image.complete && this.image.naturalWidth) {
      this.onLoad()
    } else if (this.image.complete && this.image.getAttribute('src')) {
      this.probe()
    }
  }

  disconnectedCallback () {
    this.image?.removeEventListener('load', this.onLoad)
    this.image?.removeEventListener('error', this.onError)

    this.retryButton?.removeEventListener('click', this.retry)
  }

  onLoad = () => {
    this.image.setAttribute('width', this.image.naturalWidth)
    this.image.setAttribute('height', this.image.naturalHeight)

    this.style.aspectRatio = `${this.image.naturalWidth} / ${this.image.naturalHeight}`

    this.toggleState({ loading: false, failed: false })
  }

  onError = () => {
    this.toggleState({ loading: false, failed: true })
  }

  // The image settled before this element was upgraded: confirm the failure
  // with a separate request rather than trusting `complete` on a lazy image.
  probe () {
    const probe = new Image()

    probe.addEventListener('error', () => {
      if (!this.image.naturalWidth) this.onError()
    })

    probe.src = this.image.getAttribute('src')
  }

  retry = () => {
    const src = this.image.getAttribute('src')

    this.toggleState({ loading: true, failed: false })

    this.image.removeAttribute('src')
    this.image.setAttribute('src', src)
  }

  toggleState ({ loading, failed }) {
    this.placeholder?.classList?.toggle('hidden', !loading)
    this.error?.classList?.toggle('hidden', !failed)
    this.error?.classList?.toggle('flex', failed)

    if (this.hasAttribute('aria-busy')) {
      this.setAttribute('aria-busy', loading ? 'true' : 'false')
    }
  }
})
