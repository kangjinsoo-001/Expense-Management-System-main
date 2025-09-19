# Hotwire Playbook (Rails 8)

## 0. Table of Contents

1. [Decision Protocols](#1-decision-protocols)
2. [Implementation Processes](#2-implementation-processes)
3. [Debug & Feedback Loop](#3-debug--feedback-loop)
4. [Release Readiness Checklists](#4-release-readiness-checklists)
5. [Rails 8 Defaults Summary](#5-rails-8-defaults-summary)
6. [Quick Reference](#6-quick-reference)

---

## 1. Decision Protocols

### 1‑A. Hotwire Component Matrix

| Use‑case                             | Turbo Drive | Turbo Frames | Turbo Streams | Stimulus |
| ------------------------------------ | ----------- | ------------ | ------------- | -------- |
| Full‑page navigation                 | ✅           | –            | –             | –        |
| **Partial replace inside page**      | –           | **✅**        | –             | –        |
| Server‑initiated multi‑client update | –           | –            | **✅**         | –        |
| Client‑only DOM interactions / FX    | –           | –            | –             | **✅**    |

**Rule 1:** Only escalate to “full JS SPA” if the need is ***not*** covered by the four cells above.
**Rule 2:** For any CRUD list, default to **Turbo Frames** first; switch to **Turbo Streams** only when real‑time broadcast is required.

---

## 2. Implementation Processes

### 2‑A. Turbo Frame CRUD Pattern (canonical)

```erb
<!-- app/views/posts/_row.html.erb -->
<%= turbo_frame_tag dom_id(post) do %>
  <tr id="<%= dom_id(post) %>">
    <td><%= post.title %></td>
    <td><%= link_to "Edit", edit_post_path(post),
            data: { turbo_frame: dom_id(post) } %></td>
  </tr>
<% end %>
```

1. **ID Convention** `turbo_frame_tag` id === `dom_id(record)`
2. **Link/Form Binding** Every internal navigation sets `data-turbo-frame="<same‑id>"`
3. **Partial Re‑use** Controller actions `create` & `update` both render the same `_row` partial

### 2‑B. Turbo Streams Broadcast

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  broadcasts_to ->(post) { "posts" }
end
```

```erb
<!-- app/views/posts/create.turbo_stream.erb -->
<%= turbo_stream.append "posts" do %>
  <%= render @post %>
<% end %>
```

*Add `<%= turbo_stream_from "posts" %>` in any layout that must receive live updates.*

### 2‑C. Stimulus Controller Skeleton

```
app/javascript/controllers
└─ form_controller.js
```

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  submitStart()  { this.submitTarget.classList.add("loading") }
  submitEnd()    { this.submitTarget.classList.remove("loading") }
}
```

**Naming Rule:**
`controllers/FILENAME_controller.js` → `export default class extends Controller` →
HTML: `data-controller="filename"`

---

## 3. Debug & Feedback Loop

| Step | Tool                                      | What to check                                                     |
| ---- | ----------------------------------------- | ----------------------------------------------------------------- |
| 1    | **DevTools → Network**                    | `Content-Type: text/vnd.turbo-stream`?                            |
| 2    | **Console**                               | `document.addEventListener("turbo:before-stream-render", …)` logs |
| 3    | **Stimulus DevTools / `window.Stimulus`** | Controller connection & targets                                   |
| 4    | **Hotwire Spark** (dev only)              | Live‑reload without full refresh                                  |

### Hotwire Spark Setup

```ruby
# Gemfile (development)
gem "hotwire-spark"
```

Runs after `bin/dev`; no extra commands.

---

## 4. Release Readiness Checklists

### 4‑A. Feature PR Checklist

* [ ] **Decision recorded** (Frame vs Stream vs Stimulus) in PR description
* [ ] **Partial & Frame IDs** follow `dom_id` convention
* [ ] **Single Source Partial** used by both HTML and Stream responses
* [ ] **Stimulus naming** matches `data-controller`
* [ ] **All Stream views** render valid `<turbo-stream>` markup (tested via cURL)
* [ ] **System test** exercises at least one Frame replacement and, if used, one Stream broadcast

### 4‑B. Pre‑merge Smoke Test

1. `rails test:system` passes
2. `bin/dev` + Hotwire Spark shows no console errors on CRUD operations
3. Mobile viewport sanity check (Turbo Drive navigation only)

---

## 5. Rails 8 Defaults Summary

| Area         | Rails 7                     | Rails 8 (current)                               |
| ------------ | --------------------------- | ----------------------------------------------- |
| JS bundling  | importmap **or** esbuild    | **importmap default** (esbuild optional)        |
| CSS bundling | cssbundling (tailwind etc.) | `rails css:install tailwind` wizard             |
| Hotwire      | `rails hotwire:install`     | **Built‑in by default** (omit with `--minimal`) |
| Error pages  | Static HTML                 | **Configurable branding** (color/logo)          |

Remember to pin **Turbo ^8.0** and **Stimulus ^3.2** in `package.json` until the next major.

---

## 6. Quick Reference

```
# CRUD list pattern
turbo_frame_tag dom_id(@record)
 ↳ partial: _record.html.erb
    ↳ used by .html + .turbo_stream

# Model broadcast
broadcasts_to ->(rec) { "channel_name" }

# Stimulus life‑cycle
connect() → [custom actions] → disconnect()

# Common Turbo events
turbo:before-fetch-request
turbo:before-stream-render
turbo:load
```

---

**End of file** – keep this playbook under version control and update it when Rails/Hotwire versions change.
