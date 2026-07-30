Rails.application.routes.draw do
  mount JobBoard::Engine => "/job_board"
end
