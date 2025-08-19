import 'package:flutter/material.dart';
import '../models/task.dart';
import '../utils/constants.dart';

class TaskCard extends StatefulWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppConstants.borderColor.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                onTapDown: (_) => _animationController.forward(),
                onTapUp: (_) => _animationController.reverse(),
                onTapCancel: () => _animationController.reverse(),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 12),
                      _buildDescription(),
                      const SizedBox(height: 16),
                      _buildStatusRow(),
                      const SizedBox(height: 12),
                      _buildFooterInfo(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.task.title,
            style: AppConstants.subHeaderStyle.copyWith(
              color: AppConstants.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        _buildPriorityBadge(),
      ],
    );
  }

  Widget _buildDescription() {
    return Text(
      widget.task.description,
      style: AppConstants.bodyStyle.copyWith(
        color: AppConstants.textSecondaryColor,
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatusRow() {
    return Row(
      children: [
        _buildStatusBadge(),
        const SizedBox(width: 12),
        if (widget.task.isOverdue) _buildOverdueBadge(),
        const Spacer(),
        _buildActionMenu(),
      ],
    );
  }

  Widget _buildFooterInfo() {
    return Row(
      children: [
        Icon(
          Icons.calendar_today_outlined,
          size: 14,
          color: AppConstants.textSecondaryColor,
        ),
        const SizedBox(width: 6),
        Text(
          'Due: ${_formatDate(widget.task.dueDate)}',
          style: AppConstants.captionStyle.copyWith(
            color: AppConstants.textSecondaryColor,
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Icon(
          Icons.person_outline,
          size: 14,
          color: AppConstants.textSecondaryColor,
        ),
        const SizedBox(width: 6),
        Text(
          widget.task.createdBy.name,
          style: AppConstants.captionStyle.copyWith(
            color: AppConstants.textSecondaryColor,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color statusColor = AppConstants.statusColors[widget.task.status.name] ?? 
        AppConstants.textSecondaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        widget.task.status.name.replaceAll('_', ' '),
        style: TextStyle(
          color: statusColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildPriorityBadge() {
    Color priorityColor = AppConstants.priorityColors[widget.task.priority.name] ?? 
        AppConstants.textSecondaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: priorityColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            widget.task.priority.name,
            style: TextStyle(
              color: priorityColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverdueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppConstants.errorColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning,
            size: 10,
            color: AppConstants.errorColor,
          ),
          const SizedBox(width: 4),
          Text(
            'Overdue',
            style: TextStyle(
              color: AppConstants.errorColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit' && widget.onEdit != null) {
            widget.onEdit!();
          } else if (value == 'delete' && widget.onDelete != null) {
            widget.onDelete!();
          }
        },
        color: AppConstants.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppConstants.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit',
                  style: TextStyle(
                    color: AppConstants.textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: AppConstants.errorColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delete',
                  style: TextStyle(
                    color: AppConstants.errorColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.more_vert,
            color: AppConstants.textSecondaryColor,
            size: 16,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}