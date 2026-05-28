# frozen_string_literal: true

require 'roda'
require_relative 'app'

module Tyto
  # Web controller for the Tyto Web App
  class App < Roda # rubocop:disable Metrics/ClassLength
    route('courses') do |routing|
      require_login!(routing)

      # GET /courses/new
      routing.is 'new' do
        unless @current_account.course_creator?
          flash[:error] = 'Only creators or admins can create courses'
          routing.redirect '/courses'
        end
        view 'courses/new'
      end

      routing.on String do |course_id|
        course_id = Integer(course_id, exception: false) || course_id

        routing.on 'attendances' do
          # POST /courses/[course_id]/attendances
          routing.post do
            RecordAttendance.new(App.config).call(
              @current_account,
              course_id: course_id,
              event_id: routing.params['event_id']
            )
            flash[:notice] = 'Checked in to event'
            routing.redirect "/courses/#{course_id}"
          rescue ApiClient::ApiError => e
            flash[:error] = "Could not check in: #{e.message}"
            routing.redirect "/courses/#{course_id}"
          rescue StandardError => e
            App.logger.error "ATTENDANCE ERROR: #{e.inspect}"
            flash[:error] = 'Could not record attendance'
            routing.redirect "/courses/#{course_id}"
          end
        end

        routing.on 'events' do
          # GET /courses/[course_id]/events/new
          routing.is 'new' do
            view 'courses/events/new',
                 locals: { course: GetCourse.new(App.config).call(@current_account, course_id: course_id) }
          end

          # POST /courses/[course_id]/events
          routing.post do
            validation = Tyto::Form::NewEvent.call(routing.params)
            if validation.failure?
              flash.now[:error] = Tyto::Form.validation_errors(validation)
              next view('courses/events/new', locals: {
                          course: GetCourse.new(App.config).call(@current_account, course_id: course_id)
                        })
            end

            CreateEventForCourse.new(App.config).call(
              @current_account,
              course_id: course_id,
              name: validation[:name],
              start_at: validation[:start_at],
              end_at: validation[:end_at],
              location_id: validation[:location_id]
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
            @load_maps = true
            view 'courses/locations/new', locals: { course_id: course_id }
          end

          # POST /courses/[course_id]/locations
          routing.post do
            validation = Tyto::Form::NewLocation.call(routing.params)
            if validation.failure?
              flash.now[:error] = Tyto::Form.validation_errors(validation)
              next view('courses/locations/new', locals: { course_id: course_id })
            end

            CreateLocationForCourse.new(App.config).call(
              @current_account,
              course_id: course_id,
              name: validation[:name],
              latitude: validation[:latitude],
              longitude: validation[:longitude]
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
            validation = Tyto::Form::EnrollmentByEmail.call(routing.params)
            if validation.failure?
              flash.now[:error] = Tyto::Form.validation_errors(validation)
              next view('courses/enrollments/new', locals: { course_id: course_id })
            end

            EnrollAccountInCourse.new(App.config).call(
              @current_account,
              course_id: course_id,
              username: validation[:username],
              role_name: validation[:role_name]
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
                @current_account,
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
          @load_maps = true # Course detail may render attendance maps for live events
          view 'courses/show',
               locals: {
                 course: GetCourse.new(App.config).call(@current_account, course_id: course_id),
                 current_account: @current_account,
                 my_roles: @current_account.roles_for_course(course_id)
               }
        rescue ApiClient::ApiError => e
          flash[:error] = "Could not load course: #{e.message}"
          routing.redirect '/courses'
        end
      end

      # GET /courses
      routing.get do
        view 'courses/index',
             locals: { courses: ListCourses.new(App.config).call(@current_account) }
      end

      # POST /courses
      routing.post do
        validation = Tyto::Form::NewCourse.call(routing.params)
        if validation.failure?
          flash.now[:error] = Tyto::Form.validation_errors(validation)
          next view('courses/new')
        end

        CreateCourse.new(App.config).call(
          @current_account,
          name: validation[:name],
          description: validation[:description]
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
