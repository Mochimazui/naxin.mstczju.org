# coding: utf-8
#
class FormsController < ApplicationController

  DEADLINE = Date.civil(Time.now.year, 9, 23)

  before_filter :before_deadline, :only => [ :new, :create, :update, :edit ]
  before_filter :filter_fields, :only => [ :update, :create ]

  def index
    @form = Form.find_by_id(cookies[:form_id]) if cookies[:form_id]
    @form = nil unless is_remembered?
    @deadline_exceed = (Date.today > DEADLINE)
  end

  def new
    @last_form = Form.find_by_id(cookies[:form_id]) if cookies[:form_id]
    @form = Form.new
  end

  def edit
    @form = Form.find(cookies[:form_id])

    unless is_remembered? 
      redirect_to forms_url, flash: { error: '对不起，您不能编辑这份报名表' }
    end
  end

  def create
    @form = Form.new(params[:form])

    # add staff comment
    if current_staff
      @form.comments = "由 #{current_staff.name} 提交"
    end

    @form.user_agent = request.env['HTTP_USER_AGENT']

    if @form.save
      remember
      redirect_to forms_url, notice: '恭喜，报名表已经成功提交 :)'
    else
      render action: "new"
    end
  end

  def update
    @form = Form.find(cookies[:form_id])
    
    # check belonging
    if is_remembered?
      if @form.update_attributes(params[:form])
        redirect_to forms_url, notice: '报名表更新成功 :)'
      else
        render action: "edit"
      end
    else
      redirect_to forms_url, flash: { error: '对不起，现在不能编辑这份报名表，您可以重新填写一份新的报名表' }
    end
  end

  def deadline_exceed?
    Date.today > DEADLINE
  end

  def print
    raise ActionController::MethodNotAllowed.new(:about) unless current_staff

    orders = {}
    forms = Form.nospam.pending

    params[:sort].try do |namelist|
      namelist.split(/,/).each.with_index do |name, i|
        form = forms.select(:id).find_by_name(name)
        next unless form
        orders[form.id] = i
      end
    end

    count  = forms.count
    @forms = forms.sort_by { |f| orders[f.id] || count }

    render layout: 'print'
  end

  private

  def before_deadline
    return unless deadline_exceed?

    # staff ignores deadline
    if current_staff
      flash[:notice] = '已作为 Staff 登录，无视截止日期' if deadline_exceed?
    else
      redirect_to forms_url, notice: '本次纳新报名已截止，欢迎关注 MSTC 的其他活动'
    end
  end

  def remember
    cookies.permanent[:form_id] = @form.id
    cookies.permanent.signed[:form_hash] = @form.cookie_hash = random_hash 
    @form.save
  end

  def is_remembered?
    return nil unless @form
    (cookies[:form_id] || '-').to_s == @form.id.to_s and (cookies.signed[:form_hash] || '-').to_s == @form.cookie_hash.to_s
  end

  def random_hash
    rand.hash.abs.to_s(36)
  end

  def filter_fields
    return if not params[:form]
    [:comments, :state].each { |f| params[:form].delete f }
  end

end
