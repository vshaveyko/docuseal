# frozen_string_literal: true

module Api
  # Runs the builder's field detection (Templates::DetectFields: the
  # fields-detection model plus the PDF's own text) over a template's documents
  # and answers the fields it finds, without saving them on the template.
  #
  # The builder's "Detect fields" button streams the same result over SSE to a
  # signed-in browser; this is the server-to-server form of it, for an API
  # client that wants to know where a document's blanks and tick boxes are
  # (for example to place its own prefilled fields) before it sets the
  # template's fields itself with PUT /api/templates/:id.
  class TemplatesDetectFieldsController < ApiBaseController
    load_and_authorize_resource :template

    def create
      authorize!(:update, @template)

      documents = @template.schema_documents.preload(:blob)
      documents = documents.where(uuid: params[:attachment_uuid]) if params[:attachment_uuid].present?

      fields = documents.flat_map do |document|
        io =
          if document.image?
            StringIO.new(document.preview_images.joins(:blob).find_by(blob: { filename: ['0.png', '0.jpg'] }).download)
          else
            StringIO.new(document.download)
          end

        Templates::DetectFields.call(io, attachment: document).first
      end

      render json: { fields: }
    end
  end
end
