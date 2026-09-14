# frozen_string_literal: true

describe 'templates_uploads/show' do
  before do
    # Defined on ApplicationController (a helper_method), which a view spec's
    # stand-in controller does not carry.
    view.singleton_class.define_method(:button_title) { |**| 'Open' }
  end

  # The embedded builder seeds a fresh template from a document URL and names
  # it with an `external_id` the host app reconciles against. This page is the
  # only hop between `/embed/builder` and the create, so whatever it does not
  # post back is lost: without the hidden field the template is created
  # anonymous, falls outside the embed scope (403 in the editor), and the
  # `template.created` webhook carries nothing to link it to.
  it 'posts the external_id back with the confirmed upload' do
    controller.params[:url] = 'https://example.com/doc.pdf'
    controller.params[:filename] = 'Consent_Form.pdf'
    controller.params[:external_id] = 'ext-seed'

    render

    expect(rendered).to have_css("form input[name='external_id'][value='ext-seed']", visible: :all)
  end
end
