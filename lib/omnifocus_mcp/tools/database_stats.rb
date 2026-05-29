# frozen_string_literal: true

require_relative "../result"
require_relative "../infrastructure/js_embed"
require_relative "../infrastructure/script_runner"

module OmnifocusMcp
  module Tools
    # Lightweight database overview helpers that don't require pulling the
    # full OmniFocus dataset.
    #
    # Provides:
    #   * {.get_database_stats} — counts + last-modified timestamp
    #   * {.get_changes_since}  — incremental change feed since a timestamp
    # rubocop:disable Metrics/ModuleLength
    module DatabaseStats
      # Lightweight database statistics: counts + last-modified timestamp.
      #
      # @return [OmnifocusMcp::Result] +ok+ carries the stats Hash; +error+ carries a user-facing message.
      class << self
        def get_database_stats
          require_relative "operations/database_stats"

          Operations::DatabaseStats.get_database_stats
        end

        # Incremental change feed since `since` (a Time, DateTime, or ISO string).
        #
        # @return [OmnifocusMcp::Result] +ok+ carries the changes Hash; +error+ carries a user-facing message.
        def get_changes_since(since)
          require_relative "operations/database_stats"

          Operations::DatabaseStats.get_changes_since(since)
        end

        STATS_SCRIPT = <<~JS
          (() => {
            try {
              const allTasks = flattenedTasks;
              const activeTasks = allTasks.filter(task =>
                task.taskStatus !== Task.Status.Completed &&
                task.taskStatus !== Task.Status.Dropped
              );

              const allProjects = flattenedProjects;
              const activeProjects = allProjects.filter(project =>
                project.status === Project.Status.Active
              );

              const overdueCount = activeTasks.filter(task =>
                task.taskStatus === Task.Status.Overdue
              ).length;

              const nextActionCount = activeTasks.filter(task =>
                task.taskStatus === Task.Status.Next
              ).length;

              const flaggedCount = activeTasks.filter(task => task.flagged).length;
              const inboxCount = activeTasks.filter(task => task.inInbox).length;

              let lastModified = new Date(0);
              allTasks.forEach(task => {
                if (task.modificationDate && task.modificationDate > lastModified) {
                  lastModified = task.modificationDate;
                }
              });

              return JSON.stringify({
                taskCount: allTasks.length,
                activeTaskCount: activeTasks.length,
                projectCount: allProjects.length,
                activeProjectCount: activeProjects.length,
                folderCount: flattenedFolders.length,
                tagCount: flattenedTags.filter(tag => tag.active).length,
                overdueCount: overdueCount,
                nextActionCount: nextActionCount,
                flaggedCount: flaggedCount,
                inboxCount: inboxCount,
                lastModified: lastModified.toISOString()
              });

            } catch (error) {
              return JSON.stringify({
                error: "Failed to get database stats: " + error.toString()
              });
            }
          })();
        JS

        # rubocop:disable Metrics/MethodLength
        def changes_script(since_iso)
          escaped_since = Infrastructure::JsEmbed.double_quoted_string(since_iso)

          <<~JS
            (() => {
              try {
                const sinceDate = new Date("#{escaped_since}");

                const allTasks = flattenedTasks;

                const newTasks = allTasks.filter(task =>
                  task.creationDate && task.creationDate > sinceDate
                ).map(task => ({
                  id: task.id.primaryKey,
                  name: task.name,
                  creationDate: task.creationDate.toISOString()
                }));

                const updatedTasks = allTasks.filter(task =>
                  task.modificationDate &&
                  task.modificationDate > sinceDate &&
                  task.creationDate &&
                  task.creationDate <= sinceDate
                ).map(task => ({
                  id: task.id.primaryKey,
                  name: task.name,
                  modificationDate: task.modificationDate.toISOString()
                }));

                const completedTasks = allTasks.filter(task =>
                  task.completionDate &&
                  task.completionDate > sinceDate
                ).map(task => ({
                  id: task.id.primaryKey,
                  name: task.name,
                  completionDate: task.completionDate.toISOString()
                }));

                const allProjects = flattenedProjects;

                const newProjects = allProjects.filter(project =>
                  project.creationDate && project.creationDate > sinceDate
                ).map(project => ({
                  id: project.id.primaryKey,
                  name: project.name,
                  creationDate: project.creationDate.toISOString()
                }));

                const updatedProjects = allProjects.filter(project =>
                  project.modificationDate &&
                  project.modificationDate > sinceDate &&
                  project.creationDate &&
                  project.creationDate <= sinceDate
                ).map(project => ({
                  id: project.id.primaryKey,
                  name: project.name,
                  modificationDate: project.modificationDate.toISOString()
                }));

                return JSON.stringify({
                  newTasks: newTasks,
                  updatedTasks: updatedTasks,
                  completedTasks: completedTasks,
                  newProjects: newProjects,
                  updatedProjects: updatedProjects
                });

              } catch (error) {
                return JSON.stringify({
                  error: "Failed to get changes: " + error.toString()
                });
              }
            })();
          JS
        end
        # rubocop:enable Metrics/MethodLength

        private

        # Collapse a {Infrastructure::ScriptRunner} {Result} into a {Result} over the parsed Hash payload.
        def script_payload_result(execution)
          execution.and_then do |payload|
            if payload.is_a?(Hash) && payload["error"]
              Result.error(payload["error"])
            else
              Result.ok(payload)
            end
          end
        end
      end
    end
    # rubocop:enable Metrics/ModuleLength
  end
end
