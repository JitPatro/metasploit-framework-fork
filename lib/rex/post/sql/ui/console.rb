require 'rex/post/sql/ui/console/command_dispatcher'
require 'rex/post/sql/ui/console/interactive_sql_client'

module Rex
  module Post
    module Sql
      module Ui

        #
        # Base console class for Generic SQL consoles
        #
        module Console

          include Rex::Ui::Text::DispatcherShell

          # Called when someone wants to interact with an SQL client.  It's
          # assumed that init_ui has been called prior.
          #
          # @param [Proc] block
          # @return [Integer]
          def interact(&block)
            # Run queued commands
            commands.delete_if do |ent|
              run_single(ent)
              true
            end

            # Run the interactive loop
            run do |line|
              # Run the command
              run_single(line)

              # If a block was supplied, call it, otherwise return false
              if block
                block.call
              else
                false
              end
            end
          end

          # Queues a command to be run when the interactive loop is entered.
          #
          # @param [Object] cmd
          # @return [Object]
          def queue_cmd(cmd)
            self.commands << cmd
          end

          # Runs the specified command wrapper in something to catch meterpreter
          # exceptions.
          #
          # @param [Object] dispatcher
          # @param [Object] method
          # @param [Object] arguments
          # @return [FalseClass]
          def run_command(dispatcher, method, arguments)
            begin
              super
            rescue ::Timeout::Error
              log_error('Operation timed out.')
            rescue ::Rex::InvalidDestination => e
              log_error(e.message)
            rescue ::Errno::EPIPE, ::OpenSSL::SSL::SSLError, ::IOError
              self.session.kill
            rescue ::StandardError => e
              log_error("Error running command #{method}: #{e.class} #{e}")
              elog(e)
            end
          end

          #
          # Interacts with the supplied client.
          #
          def interact_with_client(client_dispatcher: nil)
            return unless client_dispatcher

            client.extend(InteractiveSqlClient) unless client.is_a?(InteractiveSqlClient)
            client.on_command_proc = self.on_command_proc if self.on_command_proc && client.respond_to?(:on_command_proc)
            client.on_print_proc   = self.on_print_proc if self.on_print_proc && client.respond_to?(:on_print_proc)
            client.on_log_proc = method(:log_output) if self.respond_to?(:log_output, true) && client.respond_to?(:on_log_proc)
            client.client_dispatcher = client_dispatcher

            client.interact(input, output)
            client.reset_ui
          end

          #
          # Log that an error occurred.
          #
          def log_error(msg)
            print_error(msg)

            elog(msg, session.type)

            dlog("Call stack:\n#{$ERROR_POSITION.join("\n")}", session.type)
          end
        end
      end
    end
  end
end
