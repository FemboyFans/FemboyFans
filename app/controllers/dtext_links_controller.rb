# frozen_string_literal: true

class DtextLinksController < ApplicationController
  respond_to :html, :json

  def index
    @dtext_links = authorize(DtextLink).search(search_params(DtextLink)).paginate(params[:page], limit: params[:limit])
    respond_with(@dtext_links)
  end
end