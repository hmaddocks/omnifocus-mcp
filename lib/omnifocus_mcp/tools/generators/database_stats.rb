# frozen_string_literal: true

require_relative "../../infrastructure/js_embed"

module OmnifocusMcp
  module Tools
    module Generators
      class DatabaseStats
        class << self
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

          def stats_script = STATS_SCRIPT

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
        end
      end
    end
  end
end
