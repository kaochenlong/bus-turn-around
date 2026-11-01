// The home page's district filter. The server lists every route card with
// data-districts, the names of the districts the route qualifies in, and a
// select of every such name with the default district selected and already
// applied; this hides the cards that do not carry the selected name, writes
// the count line and, once the visitor changes the selection, keeps it in the
// page address, so the link can be shared. Without JavaScript the page stays
// on the default district.

// The district the page address names, when it is one of the options; ""
// otherwise, which falls back to the selected option.
export function districtFromSearch(search, options) {
  const district = new URLSearchParams(search).get("district") ?? ""
  return options.includes(district) ? district : ""
}

// Whether a card whose data-districts holds `districts`, names separated by
// spaces, shows under `district`; every card shows under "".
export function matches(districts, district) {
  return district === "" || districts.split(" ").includes(district)
}

// The Alpine component of the route list section: `district` is the select's
// value. The section is $root: $el would be the select when a method runs
// from its change handler.
export function districtFilter() {
  return {
    district: "",

    // The address wins over the server's default; the address itself is
    // left as it is until the visitor changes the selection.
    init() {
      this.district = districtFromSearch(window.location.search, this.options()) || this.selectedOption()
      this.apply()
    },

    options() {
      return [...this.$root.querySelectorAll("[data-district-filter] option")].map((option) => option.value)
    },

    // The option the server selected, the first one failing that, "" without
    // any select.
    selectedOption() {
      const select = this.$root.querySelector("[data-district-filter]")
      return select?.querySelector("option[selected]")?.value ?? select?.options[0]?.value ?? ""
    },

    change() {
      this.apply()
      this.writeAddress()
    },

    // Hides the cards outside the selected district and writes the count
    // line; without a select every card shows and there is no line.
    apply() {
      let shown = 0
      for (const card of this.$root.querySelectorAll("li[data-districts]")) {
        const visible = matches(card.dataset.districts, this.district)
        card.hidden = !visible
        if (visible) shown += 1
      }
      this.writeCount(shown)
    },

    // The line's wording comes from the server as templates with {district}
    // and {count}; data-unknown is how many listed routes have no districts
    // yet, which the filter hides along with the rest.
    writeCount(shown) {
      const line = this.$root.querySelector("[data-district-count]")
      if (!line) return
      if (this.district === "") {
        line.hidden = true
        line.textContent = ""
        return
      }
      const unknown = Number(line.dataset.unknown)
      let text = line.dataset.countTemplate.replace("{district}", this.district).replace("{count}", String(shown))
      if (unknown > 0) text += line.dataset.unknownTemplate.replace("{count}", String(unknown))
      line.textContent = text
      line.hidden = false
    },

    // Replaces the address rather than pushing one, so the back button leaves
    // the page; Turbo's own history state is kept.
    writeAddress() {
      const url = new URL(window.location.href)
      url.searchParams.set("district", this.district)
      window.history.replaceState(window.history.state, "", url)
    },
  }
}
