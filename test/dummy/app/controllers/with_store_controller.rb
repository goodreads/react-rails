class WithStoreController < ApplicationController
  def show
    @todos = %w{todo1 todo2 todo3}
  end
  def show_ajax
    @todos = %w{todo1 todo2 todo3}
  end
end
