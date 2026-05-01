# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda # rubocop:disable Metrics/ClassLength
    route('courses') do |routing|
      require_login!(routing)
      current_account_id = @current_account['id']

      # GET /courses/new
      routing.is 'new' do
        unless course_creator?(@current_account)
          flash[:error] = 'Only creators or admins can create courses'
          routing.redirect '/courses'
        end
        view 'courses/new'
      end

      routing.on String do |course_id|
        course_id = Integer(course_id, exception: false) || course_id

        routing.on 'events' do
          # GET /courses/[course_id]/events/new
          routing.is 'new' do
            view 'courses/events/new',
                 locals: { course: GetCourse.new(App.config).call(course_id, current_account_id: current_account_id) }
          end

          # POST /courses/[course_id]/events
          routing.post do
            CreateEventForCourse.new(App.config).call(
              current_account_id: current_account_id,
              course_id: course_id,
              name: routing.params['name'],
              start_at: routing.params['start_at'],
              end_at: routing.params['end_at'],
              location_id: routing.params['location_id']
            )
            flash[:notice] = 'Event scheduled'
            routing.redirect "/courses/#{course_id}"
          rescue StandardError => e
            flash[:error] = "Could not create event: #{e.message}"
            routing.redirect "/courses/#{course_id}/events/new"
          end
        end

        routing.on 'locations' do
          # GET /courses/[course_id]/locations/new
          routing.is 'new' do
            view 'courses/locations/new', locals: { course_id: course_id }
          end

          # POST /courses/[course_id]/locations
          routing.post do
            CreateLocationForCourse.new(App.config).call(
              current_account_id: current_account_id,
              course_id: course_id,
              name: routing.params['name'],
              latitude: routing.params['latitude'],
              longitude: routing.params['longitude']
            )
            flash[:notice] = 'Location added'
            routing.redirect "/courses/#{course_id}"
          rescue StandardError => e
            flash[:error] = "Could not add location: #{e.message}"
            routing.redirect "/courses/#{course_id}/locations/new"
          end
        end

        routing.on 'enrollments' do
          # GET /courses/[course_id]/enrollments/new
          routing.is 'new' do
            view 'courses/enrollments/new', locals: { course_id: course_id }
          end

          # POST /courses/[course_id]/enrollments
          routing.post do
            EnrollAccountInCourse.new(App.config).call(
              current_account_id: current_account_id,
              course_id: course_id,
              username: routing.params['username'],
              role_name: routing.params['role_name']
            )
            flash[:notice] = 'Member enrolled'
            routing.redirect "/courses/#{course_id}"
          rescue StandardError => e
            flash[:error] = "Could not enroll member: #{e.message}"
            routing.redirect "/courses/#{course_id}/enrollments/new"
          end

          # DELETE /courses/[course_id]/enrollments/[enrollment_id]
          routing.on String do |enrollment_id|
            routing.delete do
              RemoveEnrollment.new(App.config).call(
                current_account_id: current_account_id,
                course_id: course_id,
                enrollment_id: enrollment_id
              )
              flash[:notice] = 'Enrollment removed'
              routing.redirect "/courses/#{course_id}"
            rescue StandardError => e
              flash[:error] = "Could not remove enrollment: #{e.message}"
              routing.redirect "/courses/#{course_id}"
            end
          end
        end

        # GET /courses/[course_id]
        routing.get do
          view 'courses/show',
               locals: {
                 course: GetCourse.new(App.config).call(course_id, current_account_id: current_account_id),
                 current_account: @current_account,
                 my_roles: roles_for_course(course_id, @current_account)
               }
        rescue ApiClient::ApiError => e
          flash[:error] = "Could not load course: #{e.message}"
          routing.redirect '/courses'
        end
      end

      # GET /courses
      routing.get do
        view 'courses/index',
             locals: { courses: ListCourses.new(App.config).call(current_account_id: current_account_id) }
      end

      # POST /courses
      routing.post do
        CreateCourse.new(App.config).call(
          current_account_id: current_account_id,
          name: routing.params['name'],
          description: routing.params['description']
        )
        flash[:notice] = 'Course created'
        routing.redirect '/courses'
      rescue StandardError => e
        flash[:error] = "Could not create course: #{e.message}"
        routing.redirect '/courses/new'
      end
    end
  end
end
