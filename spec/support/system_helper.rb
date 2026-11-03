# frozen_string_literal: true

require "capybara/cuprite"

# Headless Chrome for browser-level layout specs. Test group only; production
# images exclude it. A missing Chrome fails the spec rather than skipping it.
CUPRITE_OPTIONS = {
  headless: true,
  process_timeout: 60,
  timeout: 30,
  protocol_timeout: 60,
  browser_options: { "no-sandbox" => nil, "disable-gpu" => nil }
}.freeze

module SystemHelper
  # Signs in through the real "Sign in with Developer" button. That button and
  # provider only exist where Rails.env.local? is true, so this stays test-only.
  def sign_in_through_browser(user)
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(
      provider: user.provider, uid: user.uid, info: { email: user.email, name: user.name }
    )
    visit "/login"
    click_button "Sign in with Developer"
    expect(page).to have_no_button("Sign in with Developer")
  end

  def resize_to(width, height = 800)
    page.current_window.resize_to(width, height)
    expect(page.evaluate_script("window.innerWidth")).to eq(width)
  end

  def page_overflow
    page.evaluate_script("document.documentElement.scrollWidth - document.documentElement.clientWidth")
  end

  # Bounding box of the first element matching the selector, in viewport coordinates.
  def box_of(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(#{selector.to_json});
        if (!el) return null;
        const r = el.getBoundingClientRect();
        return { left: r.left, right: r.right, top: r.top, bottom: r.bottom, width: r.width, height: r.height };
      })()
    JS
  end

  def computed_style(selector, property)
    page.evaluate_script("getComputedStyle(document.querySelector(#{selector.to_json})).#{property}")
  end

  def horizontal_slack(selector)
    page.evaluate_script(
      "(() => { const el = document.querySelector(#{selector.to_json}); return el.scrollWidth - el.clientWidth })()"
    )
  end

  # Left edge of every direct child, per matching row (header and body rows of a grid list).
  def column_lefts(selector)
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll(#{selector.to_json})]
        .map(row => [...row.children].map(c => Math.round(c.getBoundingClientRect().left)))
    JS
  end

  # Every pagination control in DOM order, as { left, right, top } boxes.
  def pagination_boxes
    page.evaluate_script(<<~JS)
      [...document.querySelectorAll('.join > *')].map(e => {
        const r = e.getBoundingClientRect();
        return { left: r.left, right: r.right, top: Math.round(r.top) };
      })
    JS
  end

  def pagination_row_count
    page.evaluate_script(<<~JS)
      new Set([...document.querySelectorAll('.join > *')].map(e => Math.round(e.getBoundingClientRect().top))).size
    JS
  end

  # one bounds check per side keeps failures readable
  # rubocop:disable-next Metrics/AbcSize
  def expect_inside_viewport(selector, vertical: true)
    box = box_of(selector)
    expect(box).not_to be_nil, "#{selector} not found"
    width = page.evaluate_script("window.innerWidth")
    height = page.evaluate_script("window.innerHeight")
    expect(box["left"]).to be >= -0.5, "#{selector} left=#{box['left']}"
    expect(box["right"]).to be <= width + 0.5, "#{selector} right=#{box['right']}"
    return unless vertical

    expect(box["top"]).to be >= -0.5
    expect(box["bottom"]).to be <= height + 0.5
  end
end

RSpec.configure do |config|
  config.include SystemHelper, type: :system

  config.before(:each, type: :system) do
    driven_by :cuprite, screen_size: [375, 667], options: CUPRITE_OPTIONS.deep_dup
    OmniAuth.config.test_mode = true
  end

  config.after(:each, type: :system) do
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:developer] = nil
  end
end
