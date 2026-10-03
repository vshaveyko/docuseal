# frozen_string_literal: true

describe 'submit_form/show' do
  let(:account) { create(:account) }
  let(:author) { create(:user, account:) }
  let(:template) { create(:template, account:, author:, only_field_types: %w[text]) }
  let(:submission) { create(:submission, :with_submitters, template:, created_by_user: author) }
  let(:submitter) { submission.submitters.first }

  before do
    # Defined on ApplicationController (helper_method), which a view spec's
    # stand-in controller does not carry.
    view.singleton_class.define_method(:button_title) { |**| '' }
    view.singleton_class.define_method(:current_account) { nil }
    view.singleton_class.define_method(:form_link_host) { 'example.com' }
    view.singleton_class.define_method(:svg_icon) do |icon_name, **locals|
      render(partial: "icons/#{icon_name}", locals:)
    end

    ActiveStorage::Current.url_options = { host: 'example.com' }

    Submissions.preload_with_pages(submission)

    assign(:submitter, submitter)
    assign(:form_configs, Submitters::FormConfigs.call(submitter, []))
    assign(:attachments_index, {})

    render
  end

  # Page images load progressively (and lazily), so until an image arrives its
  # page area must say so instead of showing an empty white sheet.
  it 'renders every document page with a loading placeholder behind the image' do
    pages = Capybara.string(rendered).all('page-container')

    expect(pages).not_to be_empty

    pages.each do |page|
      expect(page['aria-busy']).to eq('true')
      expect(page['style']).to match(%r{aspect-ratio: \d+ / \d+})
      expect(page).to have_css("[data-target='page-container.placeholder'][role='status']",
                               text: 'Loading document...')
      expect(page).to have_css('img[width][height]')
    end
  end

  it 'renders a hidden failed state with a retry button for every page' do
    pages = Capybara.string(rendered).all('page-container')

    expect(pages).to all(
      have_css("[data-target='page-container.error'][role='alert'].hidden",
               visible: :all, text: 'This page could not be loaded.')
      .and(have_css("button[type='button'][data-target='page-container.retryButton']",
                    visible: :all, text: 'Try again'))
    )
  end
end
