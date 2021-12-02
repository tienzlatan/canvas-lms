class ArticlesController < ApplicationController
  before_action :require_user
  before_action :get_context

  def index
    return unless authorized_action(@account, @current_user, :read_articles)

    @articles = params[:article_title] && params[:article_title].empty? ? @current_user.articles : @current_user.articles.where("title = ?", params[:article_title])
    @search_text ||= params[:article_title]
  end

  def new
    return unless authorized_action(@account, @current_user, :read_articles)

    if @current_user.nil?
      redirect_to account_articles_path
    end
    @article = Article.new
  end

  def create
    return unless authorized_action(@account, @current_user, :read_articles)

    @article = @current_user.articles.create(article_params)
    if @article.nil?
      render :new
    else
      redirect_to account_articles_path
    end
  end

  def show
    return unless authorized_action(@account, @current_user, :read_articles)

    @article = Article.find(params[:id])
  end

  def edit
    @article = Article.find(params[:id])
  end

  def update
    @article = Article.find(params[:id])

    if @article.update(article_params)
      redirect_to @article
    else
      render :edit
    end
  end

  def destroy
    return unless authorized_action(@account, @current_user, :read_articles)

    @article = Article.find(params[:id])
    @article.destroy

    redirect_to account_articles_path
  end

  private

  def article_params
    params.require(:article).permit(:title, :body)
  end
end
